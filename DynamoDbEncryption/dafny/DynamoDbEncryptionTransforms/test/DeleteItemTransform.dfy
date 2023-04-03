// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
include "../src/Index.dfy"
include "TestFixtures.dfy"

module DeleteItemTransformTest {
  import opened Wrappers
  import opened DynamoDbEncryptionTransforms
  import opened TestFixtures
  import DDB = ComAmazonawsDynamodbTypes
  import AwsCryptographyDynamoDbEncryptionTransformsTypes

  method {:test} TestDeleteItemInputPassthrough() {
    var middlewareUnderTest := TestFixtures.GetDynamoDbEncryptionTransforms();
    var input := DDB.DeleteItemInput(
      TableName := "no_such_table",
      Key := map[],
      Expected := None(),
      ConditionalOperator := None(),
      ReturnValues := None(),
      ReturnConsumedCapacity := None(),
      ReturnItemCollectionMetrics := None(),
      ConditionExpression := None(),
      ExpressionAttributeNames := None(),
      ExpressionAttributeValues := None()
    );
    var transformed := middlewareUnderTest.DeleteItemInputTransform(
      AwsCryptographyDynamoDbEncryptionTransformsTypes.DeleteItemInputTransformInput(
        sdkInput := input
      )
    );

    expect_ok("DeleteItemInput", transformed);
    expect_equal("DeleteItemInput", transformed.value.transformedInput, input);
  }

  method {:test} TestDeleteItemOutputPassthrough() {
    var middlewareUnderTest := TestFixtures.GetDynamoDbEncryptionTransforms();
    var output := DDB.DeleteItemOutput(
      Attributes := None(),
      ConsumedCapacity := None(),
      ItemCollectionMetrics := None()
    );
    var input := DDB.DeleteItemInput(
      TableName := "no_such_table",
      Key := map[],
      Expected := None(),
      ConditionalOperator := None(),
      ReturnValues := None(),
      ReturnConsumedCapacity := None(),
      ReturnItemCollectionMetrics := None(),
      ConditionExpression := None(),
      ExpressionAttributeNames := None(),
      ExpressionAttributeValues := None()
    );
    var transformed := middlewareUnderTest.DeleteItemOutputTransform(
      AwsCryptographyDynamoDbEncryptionTransformsTypes.DeleteItemOutputTransformInput(
        sdkOutput := output,
        originalInput := input
      )
    );

    expect_ok("DeleteItemOutput", transformed);
    expect_equal("DeleteItemOutput", transformed.value.transformedOutput, output);
  }
}
