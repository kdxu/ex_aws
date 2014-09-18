defmodule ExAws.Kinesis.Lazy do
  @moduledoc """
  Kinesis has a few functions that require paging.
  These functions operate just like those in ExAws.Kinesis,
  except that they return streams instead of lists that can be iterated through
  and will automatically retrieve additional pages as necessary.
  """

  @doc """
  Returns the normally shaped AWS response, except the Shards key is now a stream
  """
  def describe_stream(stream, opts \\ %{}) do
    request_fun = fn(fun_opts) ->
      ExAws.Kinesis.describe_stream(stream, Map.merge(opts, fun_opts))
    end

    ExAws.Kinesis.describe_stream(stream, opts)
      |> do_describe_stream(request_fun)
  end

  defp do_describe_stream({:error, results}, _), do: {:error, results}
  defp do_describe_stream({:ok, results}, request_fun) do
    stream = build_shard_stream({:ok, results}, request_fun)

    {:ok, put_in(results["StreamDescription"], %{"Shards" => stream})}
  end

  defp build_shard_stream(initial, request_fun) do
    Stream.resource(fn -> initial end, fn
      :quit -> {:halt, nil}

      {:error, results} -> {[{:error, results}], :quit}

      {:ok, %{"StreamDescription" => %{"Shards" => shards, "HasMoreShards" => true}}} ->
        opts = %{ExclusiveStartShardId: shards |> List.last |> Map.get("ShardId")}
        {shards, request_fun.(opts)}

      {:ok, %{"StreamDescription" => %{"Shards" => shards}}} ->
        {shards, :quit}
    end, &pass/1)
  end

  defp pass(_), do: nil
end