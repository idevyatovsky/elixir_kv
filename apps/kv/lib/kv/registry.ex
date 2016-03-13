defmodule KV.Registry do
  use GenServer

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(name) do
    # &1 : module where callbacks are implemented, current module in this case
    # &2 : init arguments (see init/1 bellow)
    # &3 : list of options

    # Pass the name to the GenServer's init
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc """
  Looks up the bucket pid for the `name` stored in `server`.

  Returns `{:ok, pid}` if the bucket exists, `:error` otherwise.
  """
  def lookup(server, name) when is_atom(server) do
    # Lookup is now donw directly in ETS, without accessng the server
    case :ets.lookup(server, name) do
      [{^name, bucket}] -> {:ok, bucket}
      [] -> :error
    end
  end

  @doc """
  Ensures there is a bucket associated to the given `name` in `server.
  """
  def create(server, name) do
    GenServer.call(server, {:create, name})
  end

  @doc """
  Stops the registry server
  """
  def stop(server) do
    GenServer.stop(server)
  end

  ## Server Callbacks

  def init(table) do
    # Replaced the names map by the ETS table
    names = :ets.new(table, [:named_table, read_concurrency: true])
    refs  = %{}
    {:ok, {names, refs}}
  end

  # The previous handle_call callback for lookup was removed

  def handle_call({:create, name}, _from, {names, refs}) do
    # receives request, and current state
    # returns tuple in the format {:noreply, new_state}

    # Read and write to the ETS table instead of the map
    case lookup(names, name) do
      {:ok, pid} ->
        {:reply, pid, {names, refs}}
      :error ->
        {:ok, pid} = KV.Bucket.Supervisor.start_bucket()
        ref = Process.monitor(pid)
        refs = Map.put(refs, ref, name)
        :ets.insert(names, {name, pid})
        {:reply, pid, {names, refs}}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, {names, refs}) do
    # Delete from the ETS table instead od the map
    {name, refs} = Map.pop(refs, ref)
    :ets.delete(names, name)
    {:noreply, {names, refs}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
