defmodule KV.Bucket do
  @doc """
  Starts a new bucket.
  """
  def start_link do
    # Starts an agent with initial state of an empty map
    Agent.start_link(fn -> %{} end)
  end

  @doc """
  Gets a `value` from the `bucket` by `key`
  """
  def get(bucket, key) do
    # &Funcname captures the function
    # &1 is the first argument
    Agent.get(bucket, &Map.get(&1, key))
  end

  @doc """
  Puts a `value` for the given `key` in the `bucket`
  """
  def put(bucket, key, value) do
    Agent.update(bucket, &Map.put(&1, key, value))
  end

  @doc """
  Deletes `key` from `bucket`

  Returns the current value of `key` if `key` exists
  """
  def delete(bucket, key) do
    # another way of sending a callable function
    Agent.get_and_update(bucket, fn dict ->
      Map.pop(dict, key)
    end)
  end
end
