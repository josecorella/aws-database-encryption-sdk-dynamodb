// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
include "../../private-aws-encryption-sdk-dafny-staging/StandardLibrary/src/StandardLibrary.dfy"
include "../src/Index.dfy"
include "../../private-aws-encryption-sdk-dafny-staging/ComAmazonawsDynamodb/Model/ComAmazonawsDynamodbTypes.dfy"
include "../../private-aws-encryption-sdk-dafny-staging/AwsCryptographicMaterialProviders/src/Index.dfy"
include "TestFixtures.dfy"

module DynamoDbItemEncryptorTest {
  import opened Wrappers
  import opened StandardLibrary.UInt
  import MaterialProviders
  import DynamoDbItemEncryptor
  import AwsCryptographyMaterialProvidersTypes
  import Types = AwsCryptographyDynamoDbItemEncryptorTypes
  import UTF8
  import DDB = ComAmazonawsDynamodbTypes
  import TestFixtures

  method {:test} TestEncryptItem() {
    // Create the Item Encryptor
    var encryptor := TestFixtures.GetDynamoDbItemEncryptor();
    
    // This method is currently stubbed, so it doesn't matter what our input is
    var inputItem := map[];

    var encryptRes := encryptor.EncryptItem(
      Types.EncryptItemInput(
        plaintextItem:=inputItem
      )
    );

    // We know what to expect back from our stubbed data
    var expectedItem := map[
      "foo" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB),
      "bar" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB),
      "fizzbuzz" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB)
    ];

    expect encryptRes.Success?;
    expect encryptRes.value.encryptedItem == expectedItem;
  }

  method {:test} TestDecryptItem() {
    // Create the Item Encryptor
    var encryptor := TestFixtures.GetDynamoDbItemEncryptor();
    
    // This method is currently stubbed, so it doesn't matter what our input is
    var inputItem := map[];

    var decryptRes := encryptor.DecryptItem(
      Types.DecryptItemInput(
        encryptedItem:=inputItem
      )
    );

    // We know what to expect from our stubbed data
    var expectedItem := map[
      "foo" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB),
      "bar" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB),
      "fizzbuzz" := DDB.AttributeValue.B(BinaryAttributeValue:=TestFixtures.EXPECTED_STUBBED_BLOB)
    ];

    expect decryptRes.Success?;
    expect decryptRes.value.plaintextItem == expectedItem;
  }
}
