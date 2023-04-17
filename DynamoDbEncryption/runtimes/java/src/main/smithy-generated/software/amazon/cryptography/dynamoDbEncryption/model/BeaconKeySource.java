// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// Do not modify this file. This file is machine generated, and any changes to it will be overwritten.
package software.amazon.cryptography.dynamoDbEncryption.model;

import java.util.Objects;

public class BeaconKeySource {
  private final SingleKeyStore single;

  private final MultiKeyStore multi;

  protected BeaconKeySource(BuilderImpl builder) {
    this.single = builder.single();
    this.multi = builder.multi();
  }

  public SingleKeyStore single() {
    return this.single;
  }

  public MultiKeyStore multi() {
    return this.multi;
  }

  public Builder toBuilder() {
    return new BuilderImpl(this);
  }

  public static Builder builder() {
    return new BuilderImpl();
  }

  public interface Builder {
    Builder single(SingleKeyStore single);

    SingleKeyStore single();

    Builder multi(MultiKeyStore multi);

    MultiKeyStore multi();

    BeaconKeySource build();
  }

  static class BuilderImpl implements Builder {
    protected SingleKeyStore single;

    protected MultiKeyStore multi;

    protected BuilderImpl() {
    }

    protected BuilderImpl(BeaconKeySource model) {
      this.single = model.single();
      this.multi = model.multi();
    }

    public Builder single(SingleKeyStore single) {
      this.single = single;
      return this;
    }

    public SingleKeyStore single() {
      return this.single;
    }

    public Builder multi(MultiKeyStore multi) {
      this.multi = multi;
      return this;
    }

    public MultiKeyStore multi() {
      return this.multi;
    }

    public BeaconKeySource build() {
      if (!onlyOneNonNull()) {
        throw new IllegalArgumentException("`BeaconKeySource` is a Union. A Union MUST have one and only one value set.");
      }
      return new BeaconKeySource(this);
    }

    private boolean onlyOneNonNull() {
      Object[] allValues = {this.single, this.multi};
      boolean haveOneNonNull = false;
      for (Object o : allValues) {
        if (Objects.nonNull(o)) {
          if (haveOneNonNull) {
            return false;
          }
          haveOneNonNull = true;
        }
      }
      return haveOneNonNull;
    }
  }
}