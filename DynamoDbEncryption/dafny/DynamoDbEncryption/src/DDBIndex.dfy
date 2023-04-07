// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

/*
  Support routines for Local and Global Index structures
*/

include "Util.dfy"
include "UpdateExpr.dfy"
include "FilterExpr.dfy"
include "../../DynamoDbEncryptionTransforms/src/DdbMiddlewareConfig.dfy"

module DynamoDBIndexSupport {

  import DDB = ComAmazonawsDynamodbTypes
  import opened AwsCryptographyDynamoDbEncryptionTypes
  import opened Wrappers
  import opened StandardLibrary
  import opened StandardLibrary.UInt
  import opened DynamoDbEncryptionUtil
  import opened DdbVirtualFields
  import UTF8
  import SortedSets
  import Seq
  import Update = DynamoDbUpdateExpr
  import SET = AwsCryptographyStructuredEncryptionTypes
  import Filter = DynamoDBFilterExpr
  import M = DdbMiddlewareConfig

  // transform beacon name to plain names
  function method UnbeaconString(s : string) : string
  {
    if ReservedPrefix <= s then
      s[|ReservedPrefix|..]
    else
      s
  }

  // transform beacon names to plain names in KeySchemaAttributeName
  function method UnbeaconKeySchemaAttributeName(s : DDB.KeySchemaAttributeName)
    : Result<DDB.KeySchemaAttributeName, AwsCryptographyDynamoDbEncryptionTypes.Error>
  {
    if ReservedPrefix <= s then
      var ret := s[|ReservedPrefix|..];
      if DDB.IsValid_KeySchemaAttributeName(ret) then
        Success(ret)
      else
        Failure(E("KeySchemaAttributeName " + s + " is invalid after removing prefix"))
    else
      Success(s)
  }

  // transform beacon names to plain names in KeySchemaElement
  function method UnbeaconKeySchemaElement(s : DDB.KeySchemaElement)
    : Result<DDB.KeySchemaElement, Error>
  {
    var name :- UnbeaconKeySchemaAttributeName(s.AttributeName);
    Success(s.(AttributeName := name))
  }

  // transform beacon names to plain names in KeySchema
  function method UnbeaconKeySchema(config : M.ValidTableConfig, schema : DDB.KeySchema)
    : Result<DDB.KeySchema, Error>
  {
    Seq.MapWithResult((k : DDB.KeySchemaElement) => UnbeaconKeySchemaElement(k), schema)
  }

  // transform beacon names to plain names in Projection
  function method UnbeaconProjection(config : M.ValidTableConfig, projection : DDB.Projection)
    : Result<DDB.Projection, Error>
  {
    if projection.NonKeyAttributes.None? then
      Success(projection)
    else
      var newAttributes := Seq.Filter((k : DDB.NonKeyAttributeName) => !(ReservedPrefix <= k), projection.NonKeyAttributes.value);
      if DDB.IsValid_NonKeyAttributeNameList(newAttributes) then
        Success(projection.(NonKeyAttributes := Some(newAttributes)))
      else
        Failure(E("Project had invalid attribute name list"))
  }

  // transform beacon names to plain names in Global Index Description
  function method TransformOneLocalIndexDescription(config : M.ValidTableConfig, index : DDB.LocalSecondaryIndexDescription)
    : Result<DDB.LocalSecondaryIndexDescription, Error>
  {
    if index.KeySchema.None? then
      Success(index)
    else
      var newSchema :- UnbeaconKeySchema(config, index.KeySchema.value);
      Success(index.(KeySchema := Some(newSchema)))
  }

  // transform beacon names to plain names in Global Index Description
  function method TransformOneGlobalIndexDescription(config : M.ValidTableConfig, index : DDB.GlobalSecondaryIndexDescription)
    : Result<DDB.GlobalSecondaryIndexDescription, Error>
  {
    var newKeySchema :-
    if index.KeySchema.None? then
      Success(None)
    else
      var schema :- UnbeaconKeySchema(config, index.KeySchema.value);
      Success(Some(schema));

    var newProjection :-
    if index.Projection.None? then
      Success(None)
    else
      var projection :- UnbeaconProjection(config, index.Projection.value);
      Success(Some(projection));

    Success(index.(KeySchema := newKeySchema, Projection := newProjection))
  }

  // transform beacon names to plain names in Local Index Descriptions
  function method TransformLocalIndexDescription(config : M.ValidTableConfig, req : Option<DDB.LocalSecondaryIndexDescriptionList>)
    : Result<Option<DDB.LocalSecondaryIndexDescriptionList>, Error>
  {
    if req.None? then
      Success(req)
    else
      var nList :- Seq.MapWithResult((d :DDB.LocalSecondaryIndexDescription) => TransformOneLocalIndexDescription(config, d), req.value);
      Success(Some(nList))
  }

  // transform beacon names to plain names in Global Index Descriptions
  function method TransformGlobalIndexDescription(config : M.ValidTableConfig, req : Option<DDB.GlobalSecondaryIndexDescriptionList>)
    : Result<Option<DDB.GlobalSecondaryIndexDescriptionList>, Error>
  {
    if req.None? then
      Success(req)
    else
      var nList :- Seq.MapWithResult((d :DDB.GlobalSecondaryIndexDescription) => TransformOneGlobalIndexDescription(config, d), req.value);
      Success(Some(nList))
  }

  predicate method IsBeacon(config : M.ValidTableConfig, name : string)
  {
    if config.search.None? then
      false
    else
      config.search.value.IsBeacon(name)
  }

  // make beacon name from attribute name
  function method MakeBeaconName(config : M.ValidTableConfig, name : string) : string
  {
    BeaconPrefix + name
  }

  // make beacon name from attribute name, fail if it's not a valid Key Schema Attribute Name
  function method MakeKeySchemaBeaconName(config : M.ValidTableConfig, name : string)
    : Result<DDB.KeySchemaAttributeName, Error>
  {
    var newName := MakeBeaconName(config, name);
    if DDB.IsValid_KeySchemaAttributeName(newName) then
      Success(newName)
    else
      Failure(E("Can't make valid KeySchemaAttributeName from beacon for " + name))
  }

  // make beacon name from attribute name, fail if it's not a valid Non Key Attribute Name
  function method MakeNonKeyBeaconName(config : M.ValidTableConfig, name : string)
    : Result<DDB.NonKeyAttributeName, Error>
  {
    var newName := MakeBeaconName(config, name);
    if DDB.IsValid_NonKeyAttributeName(newName) then
      Success(newName)
    else
      Failure(E("Can't make valid NonKeySchemaAttributeName from beacon for " + name))
  }

  // replace oldName with newName, and old type with String
  function method {:tailrecursion} ReplaceAttrDef(
    attrs : DDB.AttributeDefinitions,
    oldName : DDB.KeySchemaAttributeName,
    newName : DDB.KeySchemaAttributeName
  )
    : DDB.AttributeDefinitions
  {
    if |attrs| == 0 then
      attrs
    else if attrs[0].AttributeName == oldName then
      var newAttr := DDB.AttributeDefinition(AttributeName := newName, AttributeType := DDB.ScalarAttributeType.S);
      [newAttr] + ReplaceAttrDef(attrs[1..], oldName, newName)
    else
      [attrs[0]] + ReplaceAttrDef(attrs[1..], oldName, newName)
  }

  predicate method IsEncrypted(config : M.ValidTableConfig, attr : string)
  {
    && attr in config.itemEncryptor.config.attributeActions
    && config.itemEncryptor.config.attributeActions[attr] == SET.ENCRYPT_AND_SIGN
  }

  predicate method IsSigned(config : M.ValidTableConfig, attr : string)
  {
    && attr in config.itemEncryptor.config.attributeActions
    && config.itemEncryptor.config.attributeActions[attr] != SET.DO_NOTHING
  }

  // transform KeySchemaElement for searchable encryption, changing AttributeDefinitions as needed
  function method AddBeaconsToKeySchemaElement(
    config : M.ValidTableConfig,
    element : DDB.KeySchemaElement,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(DDB.KeySchemaElement, DDB.AttributeDefinitions), Error>
  {
    if IsBeacon(config, element.AttributeName) then
      var newName :- MakeKeySchemaBeaconName(config, element.AttributeName);
      var newAttrs := ReplaceAttrDef(attrs, element.AttributeName, newName);
      Success((element.(AttributeName := newName), newAttrs))
    else if IsEncrypted(config, element.AttributeName) then
      Failure(E("You can't make an index on an encrypted attribute, unless you've configured a beacon for that attribute."))
    else
      Success((element, attrs))
  }

  // transform Projection for searchable encryption
  // for any beacon in the Projection, add the beacon name plus any attributes used to construct the beacon
  function method AddBeaconsToProjection(config : M.ValidTableConfig, proj : DDB.Projection)
    : Result<DDB.Projection, Error>
    requires config.search.Some?
  {
    if proj.NonKeyAttributes.None? then
      Success(proj)
    else
      var newAttributes := config.search.value.GenerateClosure(proj.NonKeyAttributes.value);
      if (forall a <- newAttributes :: DDB.IsValid_NonKeyAttributeName(a)) && DDB.IsValid_NonKeyAttributeNameList(newAttributes) then
       Success(proj.(NonKeyAttributes := Some(newAttributes)))
      else
        Failure(E("Adding beacons to NonKeyAttributes of Projection in CreateGlobalSecondaryIndexAction exceeded the allowed number of projected attributes."))
  }

  // transform CreateGlobalSecondaryIndexAction for searchable encryption, changing AttributeDefinitions as needed
  function method TransformCreateGSIAction(
    config : M.ValidTableConfig,
    index : DDB.CreateGlobalSecondaryIndexAction,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(DDB.CreateGlobalSecondaryIndexAction, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    var (newKeySchema, attrs) :- AddBeaconsToKeySchema(config, index.KeySchema, attrs);
    var newProjection :- AddBeaconsToProjection(config, index.Projection);
    Success((index.(KeySchema := newKeySchema, Projection := newProjection), attrs))
  }

  // transform GSI Updates for searchable encryption, changing AttributeDefinitions as needed
  function method TransformGlobalSecondaryIndexUpdate(
    config : M.ValidTableConfig,
    index : DDB.GlobalSecondaryIndexUpdate,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(DDB.GlobalSecondaryIndexUpdate, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    if index.Create.None? then
      Success((index, attrs))
    else
      var (create, attrs) :- TransformCreateGSIAction(config, index.Create.value, attrs);
      Success((index.(Create := Some(create)), attrs))
  }

  // transform IndexUpdates for searchable encryption, changing AttributeDefinitions as needed
  function method {:tailrecursion} TransformIndexUpdates(
    config : M.ValidTableConfig,
    indexes : DDB.GlobalSecondaryIndexUpdateList,
    attrs : DDB.AttributeDefinitions,
    acc : DDB.GlobalSecondaryIndexUpdateList := []
  )
    : Result<(DDB.GlobalSecondaryIndexUpdateList, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    if |indexes| == 0 then
      Success((acc, attrs))
    else
      var (newIndex, newAttrs) :- TransformGlobalSecondaryIndexUpdate(config, indexes[0], attrs);
    TransformIndexUpdates(config, indexes[1..], newAttrs, acc + [newIndex])
  }

  // transform KeySchema for searchable encryption, changing AttributeDefinitions as needed
  function method {:tailrecursion} AddBeaconsToKeySchema(
    config : M.ValidTableConfig,
    schema : seq<DDB.KeySchemaElement>,
    attrs : DDB.AttributeDefinitions,
    acc : seq<DDB.KeySchemaElement> := [],
    origSize : nat := |schema|
  )
    : (ret : Result<(DDB.KeySchema, DDB.AttributeDefinitions), Error>)
    requires 1 <= origSize <= 2
    requires |schema| + |acc| == origSize
    ensures ret.Success? ==> |ret.value.0| == origSize
  {
    if |schema| == 0 then
      Success((acc, attrs))
    else
      var (newSchema, newAttrs) :- AddBeaconsToKeySchemaElement(config, schema[0], attrs);
      AddBeaconsToKeySchema(config, schema[1..], newAttrs, acc + [newSchema], origSize)
  }

  // transform LSI for searchable encryption, changing AttributeDefinitions as needed
  function method TransformOneLsi(
    config : M.ValidTableConfig,
    index : DDB.LocalSecondaryIndex,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(DDB.LocalSecondaryIndex, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    var (newSchema, newAttrs) :- AddBeaconsToKeySchema(config, index.KeySchema, attrs);
    var newProjection :- AddBeaconsToProjection(config, index.Projection);
    Success((index.(KeySchema := newSchema, Projection := newProjection), newAttrs))
  }

  // transform GSI for searchable encryption, changing AttributeDefinitions as needed
  function method TransformOneGsi(
    config : M.ValidTableConfig,
    index : DDB.GlobalSecondaryIndex,
    attrs : DDB.AttributeDefinitions
  )
    : Result<(DDB.GlobalSecondaryIndex, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    var (newSchema, newAttrs) :- AddBeaconsToKeySchema(config, index.KeySchema, attrs);
    var newProjection :- AddBeaconsToProjection(config, index.Projection);
    Success((index.(KeySchema := newSchema, Projection := newProjection), newAttrs))
  }

  // transform LSIs for searchable encryption, changing AttributeDefinitions as needed
  function method LsiWithAttrs(
    config : M.ValidTableConfig,
    indexes : DDB.LocalSecondaryIndexList,
    attrs : DDB.AttributeDefinitions,
    acc : DDB.LocalSecondaryIndexList := []
  )
    : Result<(DDB.LocalSecondaryIndexList, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    if |indexes| == 0 then
      Success((acc, attrs))
    else
      var (newIndex, newAttrs) :- TransformOneLsi(config, indexes[0], attrs);
      LsiWithAttrs(config, indexes[1..], newAttrs, acc + [newIndex])
  }

  // transform GSIs for searchable encryption, changing AttributeDefinitions as needed
  function method GsiWithAttrs(
    config : M.ValidTableConfig,
    indexes : DDB.GlobalSecondaryIndexList,
    attrs : DDB.AttributeDefinitions,
    acc : DDB.GlobalSecondaryIndexList := []
  )
    : Result<(DDB.GlobalSecondaryIndexList, DDB.AttributeDefinitions), Error>
    requires config.search.Some?
  {
    if |indexes| == 0 then
      Success((acc, attrs))
    else
      var (newIndex, newAttrs) :- TransformOneGsi(config, indexes[0], attrs);
      GsiWithAttrs(config, indexes[1..], newAttrs, acc + [newIndex])
  }
}