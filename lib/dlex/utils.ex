defmodule Dlex.Utils do
  @doc """
  Encode variables
  """
  def encode_vars(vars) do
    for {key, value} <- vars, into: %{}, do: {key, to_string(value)}
  end

  @doc """
  Add temporary blank ids to json object
  """
  def add_blank_ids(statement, uid_key \\ "uid"),
    do: statement |> add_blank_ids(0, uid_key) |> elem(0)

  defp add_blank_ids(list, counter, uid_key) when is_list(list) do
    {list, counter} =
      Enum.reduce(list, {[], counter}, fn map, {acc, counter} ->
        {map, counter} = add_blank_ids(map, counter, uid_key)
        {[map | acc], counter}
      end)

    {Enum.reverse(list), counter}
  end

  defp add_blank_ids(map, counter, uid_key) when is_map(map) do
    cond do
      is_location?(map) or
          (Map.has_key?(map, :__struct__) and !Map.has_key?(map, :uid)) ->
        {map, counter}

      true ->
        map = Map.update(map, uid_key, "_:#{counter}", &(&1 || "_:#{counter}"))
        :maps.fold(&do_add_blank_ids(&1, &2, &3, uid_key), {%{}, counter + 1}, map)
    end
  end

  defp add_blank_ids(value, counter, _uid_key), do: {value, counter}

  defp do_add_blank_ids(key, value, {map, counter}, uid_key) do
    {value, counter} = add_blank_ids(value, counter, uid_key)
    {Map.put(map, key, value), counter}
  end

  defp is_location?(map) do
    map_size(map) == 2 and
      (match?(%{type: _, coordinates: _}, map) or match?(%{"type" => _, "coordinates" => _}, map))
  end

  @doc """
  Replace temporary blank ids to real ids
  """
  def replace_ids(json, uids, uid_key \\ "uid")

  def replace_ids(json, uids, uid_key) when is_list(json),
    do: Enum.map(json, &replace_ids(&1, uids, uid_key))

  def replace_ids(map, uids, uid_key) when is_map(map),
    do: :maps.fold(&replace_kv(&1, &2, &3, uids, uid_key), map, map)

  def replace_ids(value, _uids, _uid_key), do: value

  defp replace_kv(uid_key, "_:" <> blank_id, map, uids, uid_key),
    do: Map.put(map, uid_key, uids[blank_id])

  defp replace_kv(key, value, map, uids, uid_key) do
    if is_map(value) or is_list(value),
      do: Map.put(map, key, replace_ids(value, uids, uid_key)),
      else: map
  end
end
