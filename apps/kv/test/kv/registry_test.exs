defmodule KV.RegistryTest do
  use ExUnit.Case, async: true

  alias KV.Registry
  alias KV.Bucket

  setup context do
    {:ok, _} = Registry.start_link(context.test)
    {:ok, registry: context.test}
  end

  test "spawn buckets", %{registry: registry} do
    assert Registry.lookup(registry, "shopping") == :error

    # Registry creates the bucket and updates the cache table
    # Since `KV.Registry.create/2` is a cast operation,
    # the command returns BEFORE we actually write to the table,
    # (asynchronous) callback
    Registry.create(registry, "shopping")
    assert {:ok, bucket} = Registry.lookup(registry, "shopping")

    Bucket.put(bucket, "milk", 1)
    assert Bucket.get(bucket, "milk") == 1
  end

  test "removes buckets on exit", %{registry: registry} do
    Registry.create(registry, "shopping")
    {:ok, bucket} = Registry.lookup(registry, "shopping")

    Agent.stop(bucket)
    # Do a call to ensure the registry processed the down message
    _ = Registry.create(registry, "bogus")
    assert Registry.lookup(registry, "shopping") == :error
  end

  test "removes bucket on crash", %{registry: registry} do
    Registry.create(registry, "shopping")
    {:ok, bucket} = Registry.lookup(registry, "shopping")

    # Stops the bucket with non-normal reason
    Process.exit(bucket, :shutdown)

    # Wait until the bucket is dead
    ref = Process.monitor(bucket)
    # Opposite to Agent.stop/1, Process.exit/2 is an asynchronous operation,
    # therefore we cannot simply query KV.Registry.lookup/2 right after
    # sending the exit signal because there will be no guarantee the bucket will
    # be dead by then
    assert_receive {:DOWN, ^ref, _, _, _}

    # Do a call to ensure the registry processed the down message
    _ = Registry.create(registry, "bogus")
    assert Registry.lookup(registry, "shopping") == :error
  end

end
