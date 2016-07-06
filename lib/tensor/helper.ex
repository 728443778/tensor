defmodule Tensor.Helper do

  # LISTS

  @doc """
  Swaps the element at position `pos_a` with the element at position `pos_b` inside a list.

  TODO: Move to a separate module with helper functions.

  # Examples

    iex> swap_elems_in_list([1,2,3,4,5], 1, 3)
    [1, 4, 3, 2, 5]
  """
  def swap_elems_in_list(list, pos_a, pos_b) do
    #IO.inspect [list, pos_a, pos_b]
    a = Enum.fetch!(list, pos_a)
    b = Enum.fetch!(list, pos_b)
    
    list
    |> List.replace_at(pos_a, b)
    |> List.replace_at(pos_b, a)
  end

  # MAPS

  @doc """
  Puts `val` under `map` inside a nested map indicated with `keys`.
  This is required, as the normal `put_in` will fail if one of the levels
  indicated by `keys` is not initialized to a map yet.

  TODO: Move to a separate module with helper functions.

  ## Examples:

    iex>put_in_path(%{}, [1,2,3], 4)
    %{1 => %{2 => %{3 => 4}}}
  """
  def put_in_path(map, keys, val) do
    do_put_in_path(map, keys, val, [])
  end

  defp do_put_in_path(map, [key], val, acc) do
    new_acc = acc ++ [key]
    put_in(map, new_acc, val)
  end

  defp do_put_in_path(map, [key | keys], val, acc) do
    new_acc = acc ++ [key]
    #IO.inspect([map, key, keys, val, acc, new_acc])
    new_map = put_in(map, new_acc, get_in(map, new_acc) || %{})
    do_put_in_path(new_map, keys, val, new_acc)
  end
end