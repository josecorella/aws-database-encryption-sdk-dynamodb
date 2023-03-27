// Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// Do not modify this file. This file is machine generated, and any changes to it will be overwritten.
package software.amazon.cryptography.dynamoDbEncryption.model;

import java.util.Objects;

public class StandardBeacon {
  private final String name;

  private final int length;

  private final String loc;

  protected StandardBeacon(BuilderImpl builder) {
    this.name = builder.name();
    this.length = builder.length();
    this.loc = builder.loc();
  }

  public String name() {
    return this.name;
  }

  public int length() {
    return this.length;
  }

  public String loc() {
    return this.loc;
  }

  public Builder toBuilder() {
    return new BuilderImpl(this);
  }

  public static Builder builder() {
    return new BuilderImpl();
  }

  public interface Builder {
    Builder name(String name);

    String name();

    Builder length(int length);

    int length();

    Builder loc(String loc);

    String loc();

    StandardBeacon build();
  }

  static class BuilderImpl implements Builder {
    protected String name;

    protected int length;

    protected String loc;

    protected BuilderImpl() {
    }

    protected BuilderImpl(StandardBeacon model) {
      this.name = model.name();
      this.length = model.length();
      this.loc = model.loc();
    }

    public Builder name(String name) {
      this.name = name;
      return this;
    }

    public String name() {
      return this.name;
    }

    public Builder length(int length) {
      this.length = length;
      return this;
    }

    public int length() {
      return this.length;
    }

    public Builder loc(String loc) {
      this.loc = loc;
      return this;
    }

    public String loc() {
      return this.loc;
    }

    public StandardBeacon build() {
      if (Objects.isNull(this.name()))  {
        throw new IllegalArgumentException("Missing value for required field `name`");
      }
      if (Objects.isNull(this.length()))  {
        throw new IllegalArgumentException("Missing value for required field `length`");
      }
      if (Objects.nonNull(this.length()) && this.length() < 1) {
        throw new IllegalArgumentException("`length` must be greater than or equal to 1");
      }
      if (Objects.nonNull(this.length()) && this.length() > 63) {
        throw new IllegalArgumentException("`length` must be less than or equal to 63.");
      }
      if (Objects.nonNull(this.loc()) && this.loc().length() < 1) {
        throw new IllegalArgumentException("The size of `loc` must be greater than or equal to 1");
      }
      return new StandardBeacon(this);
    }
  }
}