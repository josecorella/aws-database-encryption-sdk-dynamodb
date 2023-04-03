// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

include "DynamoDbMiddlewareSupport.dfy"

module TransactWriteItemsTransform {
  import opened DdbMiddlewareConfig
  import opened DynamoDbMiddlewareSupport
  import opened Wrappers
  import DDB = ComAmazonawsDynamodbTypes
  import opened AwsCryptographyDynamoDbEncryptionTransformsTypes
  import EncTypes = AwsCryptographyDynamoDbEncryptionItemEncryptorTypes
  import Seq

  predicate method {:opaque} IsValid(item : DDB.TransactWriteItem) {
    || item.Put.Some?
    || item.Update.Some?
    || item.Delete.Some?
    || item.ConditionCheck.Some?
  }

  method {:vcs_split_on_every_assert} Input(config: Config, input: TransactWriteItemsInputTransformInput)
    returns (output: Result<TransactWriteItemsInputTransformOutput, Error>)
    requires ValidConfig?(config)
    ensures ValidConfig?(config)
    modifies ModifiesConfig(config)

    ensures output.Success? ==> |output.value.transformedInput.TransactItems| == |input.sdkInput.TransactItems|

    //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
    //# To protect against a possible fifth field being added to the TransactWriteItem structure in the future,
    //# the client MUST fail if none of the `Update`, `ConditionCheck`, `Delete` and `Put` fields are set.
    ensures output.Success? ==>
      forall item <- input.sdkInput.TransactItems :: IsValid(item)
  {
    :- Need(forall item <- input.sdkInput.TransactItems :: IsValid(item), E("Each item in TransactWriteItems must specify at least one supported operation"));
    var result : seq<DDB.TransactWriteItem> := [];
    for x := 0 to |input.sdkInput.TransactItems|
      invariant |result| == x
    {
      var item := input.sdkInput.TransactItems[x];

      if item.ConditionCheck.Some? && item.ConditionCheck.value.TableName in config.tableEncryptionConfigs {
        var tableConfig := config.tableEncryptionConfigs[item.ConditionCheck.value.TableName];
        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The ConditionExpression of the `ConditionCheck` MUST be [valid](ddb-support.md#testconditionexpression).
        var _ :- TestConditionExpression(tableConfig,
          Some(item.ConditionCheck.value.ConditionExpression),
          item.ConditionCheck.value.ExpressionAttributeNames,
          item.ConditionCheck.value.ExpressionAttributeValues);
      }
      if item.Delete.Some? && item.Delete.value.TableName in config.tableEncryptionConfigs {
        var tableConfig := config.tableEncryptionConfigs[item.Delete.value.TableName];
        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The ConditionExpression of the `Delete` MUST be [valid](ddb-support.md#testconditionexpression).
        var _ :- TestConditionExpression(tableConfig,
          item.Delete.value.ConditionExpression,
          item.Delete.value.ExpressionAttributeNames,
          item.Delete.value.ExpressionAttributeValues);
      }
      if item.Update.Some? && item.Update.value.TableName in config.tableEncryptionConfigs {
        var tableConfig := config.tableEncryptionConfigs[item.Update.value.TableName];
        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The UpdateExpression of the `Update` MUST be [valid](ddb-support.md#testupdateexpression).
        var _ :- TestUpdateExpression(tableConfig,
          Some(item.Update.value.UpdateExpression),
          item.Update.value.ExpressionAttributeNames,
          item.Update.value.ExpressionAttributeValues);
        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The ConditionExpression of the `Update` MUST be [valid](ddb-support.md#testconditionexpression).
        var _ :- TestConditionExpression(tableConfig,
          item.Update.value.ConditionExpression,
          item.Update.value.ExpressionAttributeNames,
          item.Update.value.ExpressionAttributeValues);
      }

      if item.Put.Some? && item.Put.value.TableName in config.tableEncryptionConfigs {
        var tableConfig := config.tableEncryptionConfigs[item.Put.value.TableName];

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The Item MUST be [writable](ddb-support.md#writable).
        var _ :- IsWriteable(tableConfig, item.Put.value.Item);

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The ConditionExpression `Put` MUST be [valid](ddb-support.md#testconditionexpression).
        var _ :- TestConditionExpression(tableConfig,
          item.Put.value.ConditionExpression,
          item.Put.value.ExpressionAttributeNames,
          item.Put.value.ExpressionAttributeValues);

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - Beacons MUST be [added](ddb-support.md#addbeacons).
        var beaconItem :- AddBeacons(tableConfig, item.Put.value.Item);

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - If the request is validated,
        //# the [Item Encryptor](./ddb-item-encryptor.md) MUST perform
        //# [Encrypt Item](./encrypt-item.md),
        //# where the input [DynamoDB Item](./encrypt-item.md#dynamodb-item)
        //# is output of the [add beacons](ddb-support.md#addbeacons) operation.
        var encryptRes := tableConfig.itemEncryptor.EncryptItem(
          EncTypes.EncryptItemInput(plaintextItem:=beaconItem)
        );
        var encrypted :- MapError(encryptRes);

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# - The PutItem request's `Item` field MUST be replaced
        //# with a value that is equivalent to
        //# the result [Encrypted DynamoDB Item](./encrypt-item.md#encrypted-dynamodb-item)
        //# calculated above.
        var put := Some(item.Put.value.(Item := encrypted.encryptedItem));
        var newItem := item.(Put := put);
        result := result + [newItem];
      } else {
        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# Any actions other than `Put, MUST be unchanged.

        //= specification/dynamodb-encryption-client/ddb-sdk-integration.md#encrypt-before-transactwriteitems
        //# Any `Put` actions  with a `TableName` that does not refer to an [encrypted-table](#encrypted-table),
        //# MUST be unchanged.
        result := result + [item];
      }
    }
    var finalResult := result; // TODO we need to redeclare this in a "final" var until we upgrade to Dafny 3.10.0
    return Success(TransactWriteItemsInputTransformOutput(transformedInput := input.sdkInput.(TransactItems := finalResult)));
  }

  method Output(config: Config, input: TransactWriteItemsOutputTransformInput)
    returns (output: Result<TransactWriteItemsOutputTransformOutput, Error>)
    ensures output.Success? && output.value.transformedOutput == input.sdkOutput
  {
    var finalResult := input.sdkOutput;
    return Success(TransactWriteItemsOutputTransformOutput(transformedOutput := finalResult));
  }

}
