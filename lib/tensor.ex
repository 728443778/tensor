defmodule Tensor do
  defstruct [:identity, contents: %{}, dimensions: [1]]

  defimpl Inspect do
    def inspect(tensor, opts) do 
      case length(tensor.dimensions) do
        1 ->
          Vector.Inspect.inspect(tensor, opts)
        2 ->
          Matrix.Inspect.inspect(tensor, opts)
        _ ->
          "#Tensor-(#{tensor.dimensions |> Enum.join("×")}) (#{inspect tensor.contents})"
      end
    end
  end

  defmodule ArithmeticError do
    defexception message: "This arithmetic operation is not allowed when working with Vectors/Matrices/Tensors."
  end

  defmodule AccessError do
    defexception [:message]

    def exception(key) do
      %AccessError{message: "The requested key `#{inspect key}` could not be found inside this Vector/Matrix/Tensor. It probably is out of range"}
    end
  end

  defmodule CollectableError do 
    defexception [:message]

    def exception(value), do: %CollectableError{message: """
    Could not insert `#{inspect value}` to the Vector/Matrix/Tensor.
    Make sure that you pass in a list of Tensors that are order n-1 from the tensor you add them to,
    and that they have the same dimensions (save for the highest one).

    For instance, you can only add vectors of length 3 to a n×3 matrix,
    and matrices of size 2×4 can only be added to an order-3 tensor of size n×2×3 
    """}
  end

  @opaque tensor :: %Tensor{}

  @doc """
  Returs true if the tensor is a 1-order Tensor, which is also known as a Vector.
  """
  def vector?(%Tensor{dimensions: [_]}), do: true
  def vector?(%Tensor{}), do: false

  @doc """
  Returs true if the tensor is a 2-order Tensor, which is also known as a Matrix.
  """
  def matrix?(%Tensor{dimensions: [_,_]}), do: true
  def matrix?(%Tensor{}), do: false


  @doc """
  Returns the _order_ of the Tensor.

  This is 1 for Vectors, 2 for Matrices, etc.
  It is the amount of dimensions the tensor has.
  """
  def order(tensor) do
    length(tensor.dimensions)
  end

  @doc """
  Returns the dimensions of the tensor.
  """
  def dimensions(tensor = %Tensor{}) do 
    tensor.dimensions
  end

  @doc """
  Returns the identity, the default value a tensor inserts at a position when no other value is set.

  This is mostly used internally, and is used to allow Tensors to take a lot less space because 
  only values that are not `empty` have to be stored.
  """
  def identity(tensor = %Tensor{}) do 
    tensor.identity
  end


  @behaviour Access

  @doc """
  Returns a Tensor of one order less, containing all fields for which the highest-order accessor matches.
  In the case of a Vector, returns the bare value at the given location.

  `key` has to be an integer, smaller than the size of the highest dimension of the tensor. 
  When `key` is negative, we will look from the right side of the Tensor.

  This is part of the Access Behaviour implementation for Tensor.
  """
  def fetch(tensor = %Tensor{dimensions: [current_dimension|_]}, key) do
    key = (key < 0) && (current_dimension + key) || key
    if !is_number(key) || key >= current_dimension do
      raise Tensor.AccessError, key
    end
    if vector?(tensor) do # Return item inside vector.
      {:ok, Map.get(tensor.contents, key, tensor.identity)}
    else
      # Return lower dimension slice of tensor.
      contents = Map.get(tensor.contents, key, %{})
      if contents do
        dimensions = tl(tensor.dimensions)
        {:ok, %Tensor{identity: tensor.identity, contents: contents, dimensions: dimensions}}
      else 
        :error
      end
    end
  end

  @doc """
  Returns and removes the value associated with `key` from the tensor.

  `key` has to be an integer, smaller than the size of the highest dimension of the tensor. 
  When `key` is negative, we will look from the right side of the Tensor.

  Notice that because of how Tensors are structured, the structure of the tensor will not change.
  Values are basically reset to the 'identity' value.

  This is part of the Access Behaviour implementation for Tensor.
  """
  def pop(tensor = %Tensor{dimensions: [current_dimension|_]}, key, default \\ nil) do
    key = (key < 0) && (current_dimension + key) || key
    if !is_number(key) || key >= current_dimension do
      raise Tensor.AccessError, key
    end
    Map.pop(tensor.contents, key, default)
  end

  # TODO: Ensure that identity values are not stored.
  @doc """
  Gets the value inside `tensor` at key `key`, and calls the passed function `fun` on it, 
  which might update it, or return `:pop` if it ought to be removed.


  `key` has to be an integer, smaller than the size of the highest dimension of the tensor. 
  When `key` is negative, we will look from the right side of the Tensor.

  """
  def get_and_update(tensor  = %Tensor{dimensions: [current_dimension|_]}, key, fun) do
    key = (key < 0) && (current_dimension + key) || key
    if !is_number(key) || key >= current_dimension do
      raise Tensor.AccessError, key
    end
    {result, contents} = 
      if vector? tensor do
        {result, contents} = Map.get_and_update(tensor.contents, key, fun)
      else
        {:ok, ll_tensor} = fetch(tensor, key)
        {result, ll_tensor2} = fun.(ll_tensor)
        {result, Map.put(tensor.contents, key, ll_tensor2.contents)}
      end
    {result, %Tensor{tensor | contents: contents}}
  end



  @doc """
  Creates a new Tensor from a list of lists (of lists of lists of ...).
  The second argument should be the dimensions the tensor should become.
  The optional third argument is an identity value for the tensor, that all non-set values will default to.

  TODO: Solve this, maybe find a nicer way to create tensors.
  """
  def new(nested_list_of_values, dimensions \\ nil, identity \\ 0) do
    dimensions = dimensions || [length(nested_list_of_values)]
    # TODO: Dimension inference.
    contents = 
      nested_list_of_values
      |> nested_list_to_nested_map
    %Tensor{contents: contents, identity: identity, dimensions: dimensions}
  end


  defp nested_list_to_nested_map(list) do
    list
    |> Enum.with_index
    |> Enum.reduce(%{}, fn 
      {sublist, index}, map when is_list(sublist) ->
        Map.put(map, index, nested_list_to_nested_map(sublist))
      {item, index}, map -> 
        Map.put(map, index, item)
    end)
  end

  @doc """
  Returns the tensor as a nested list of lists (of lists of lists ..., depending on the order of the Tensor)
  """
  def to_list(tensor) do
    do_to_list(tensor.contents, tensor.dimensions, tensor.identity)
  end

  defp do_to_list(tensor_contents, [dimension | dimensions], identity) when dimension <= 0 do
    []
  end

  defp do_to_list(tensor_contents, [dimension], identity) do
    for x <- 0..dimension-1 do
      Map.get(tensor_contents, x, identity)
    end
  end

  defp do_to_list(tensor_contents, [dimension | dimensions], identity) do
    for x <- 0..dimension-1 do 
      do_to_list(Map.get(tensor_contents, x, %{}), dimensions, identity)
    end
  end

  @doc """
  `lifts` a Tensor up one order, by adding a dimension of size `1` to the start.

  This transforms a length-`n` Vector to a 1×`n` Matrix, a `n`×`m` matrix to a `1`×`n`×`m` 3-order Tensor, etc.

  See also `Tensor.slices/1`
  """
  def lift(tensor) do
    %Tensor{
      identity: tensor.identity, 
      dimensions: [1|tensor.dimensions], 
      contents: %{0 => tensor.contents}
    }
  end

  @doc """
  Maps `fun` over all values in the Tensor.

  This is a _true_ mapping operation, as the result will be a new Tensor.

  `fun` gets the current value as input, and should return the new value to use.

  It is important that `fun` is a pure function, as internally it will only be mapped over all values
  that are non-empty, and once over the identity of the tensor.
  """
  @spec map(tensor, (any -> any)) :: tensor
  def map(tensor, fun) do
    new_identity = fun.(tensor.identity)
    new_contents = do_map(tensor.contents, tensor.dimensions, fun)
    %Tensor{tensor | identity: new_identity, contents: new_contents}
  end

  def do_map(tensor_contents, [dimension], fun) do
    for {k,v} <- tensor_contents, into: %{} do
      {k, fun.(v)}
    end
  end

  def do_map(tensor_contents, [dimension|dimensions], fun) do
    for {k,v} <- tensor_contents, into: %{} do
      {k, do_map(v, dimensions, fun)}
    end
  end

  @doc """
  Returns a new tensor, where all values are `{list_of_coordinates, value}` tuples.

  Note that this new tuple is always dense, as the coordinates of all values are different.
  The identity is left unchanged.
  """
  def with_coordinates(tensor = %Tensor{}) do
    with_coordinates(tensor, [])
  end
  def with_coordinates(tensor = %Tensor{dimensions: [current_dimension]}, coordinates) do
    for i <- 0..(current_dimension-1), into: %Tensor{dimensions: [0]} do
      {[i|coordinates], tensor[i]}
    end
  end

  def with_coordinates(tensor = %Tensor{dimensions: [current_dimension | lower_dimensions]}, coordinates) do
    for i <- 0..(current_dimension-1), into: %Tensor{dimensions: [0 | lower_dimensions]} do
      with_coordinates(tensor[i], [i|coordinates])
    end
  end

  @doc """
  Maps a function over the values in the tensor.

  The function will receive a tuple of the form {list_of_coordinates, value}.

  Note that only the values that are not the same as the identity will call the function.
  Finally, the function will be called once to calculate the new identity. This call will be of shape {:identity, value}.

  Because of this _sparse/lazy_ invocation, it is important that `fun` is a pure function, as this is the only way
  to guarantee that the results will be the same, regardless of at what place the identity is used.
  """
  def sparse_map_with_coordinates(tensor, fun) do
    new_identity = fun.({:identity, tensor.identity})
    new_contents = do_sparse_map_with_coordinates(tensor.contents, tensor.dimensions, fun, [])
    %Tensor{tensor | identity: new_identity, contents: new_contents}
  end

  def do_sparse_map_with_coordinates(tensor_contents, [dimension], fun, coordinates) do
    for {k,v} <- tensor_contents, into: %{} do
      {k, fun.({[k|coordinates], v})}
    end
  end

  def do_sparse_map_with_coordinates(tensor_contents, [dimension|dimensions], fun, coordinates) do
    for {k,v} <- tensor_contents, into: %{} do
      {k, do_sparse_map_with_coordinates(v, dimensions, fun, [k|coordinates])}
    end
  end

  @doc """
  Maps a function over _all_ values in the tensor, including all values that are equal to the tensor identity.

  The function will receive a tuple of the form {list_of_coordinates, value},
  """
  def dense_map_with_coordinates(tensor, fun) do
    new_contents = do_dense_map_with_coordinates(tensor, tensor.dimensions, fun, [])
  end

  def do_dense_map_with_coordinates(tensor, [dimension], fun, coordinates) do
    for i <- 0..(dimension-1), into: %Tensor{dimensions: [0]} do
      fun.({[i|coordinates], tensor[i]})
    end
  end

  def do_dense_map_with_coordinates(tensor, [dimension|lower_dimensions], fun, coordinates) do
    for i <- 0..(dimension-1), into: %Tensor{dimensions: [0|lower_dimensions]} do
      do_dense_map_with_coordinates(tensor[i], lower_dimensions, fun, [i|coordinates])
    end
  end


  @doc """
  Returns a list containing all lower-dimension Tensors in the Tensor.

  For a Vector, this will just be a list of values.
  For a Matrix, this will be a list of rows.
  For a order-3 Tensor, this will be a list of matrices, etc.
  """
  def slices(tensor = %Tensor{dimensions: [current_dimension | lower_dimensions]}) do
    for i <- 0..current_dimension-1 do
      tensor[i]
    end
  end

  @doc """
  Builds up a tensor from a list of slices in a lower dimension.
  A list of values will build a Vector.
  A list of same-length vectors will create a Matrix.
  A list of same-size matrices will create an order-3 Tensor.
  """
  def from_slices(list_of_slices = [%Tensor{dimensions: dimensions , identity: identity} | _rest]) do
    Enum.into(list_of_slices, Tensor.new([], [0 | dimensions], identity))
  end

  def from_slices(list_of_values) do
    Tensor.new(list_of_values)
  end

  @doc """
  Adds the number `b` to all elements in Tensor `a`.
  """
  def add_number(a = %Tensor{dimensions: [l]}, b) when is_number(b) do
    Tensor.map(a, &(&1 + b))
  end

  def mul_number(a = %Tensor{dimensions: [l]}, b) when is_number(b) do
    Tensor.map(a, &(&1 * b))
  end

  def sub_number(a = %Tensor{dimensions: [l]}, b) when is_number(b) do
    Tensor.map(a, &(&1 - b))
  end

  def div_number(a = %Tensor{dimensions: [l]}, b) when is_number(b) do
    Tensor.map(a, &(&1 / b))
  end



  defimpl Enumerable do
    
    def count(tensor), do: {:ok, Enum.reduce(tensor.dimensions, 1, &(&1 * &2))}
  
    def member?(tensor, element), do: {:error, __MODULE__}

    def reduce(tensor, acc, fun) do
      tensor
      |> Tensor.slices
      |> do_reduce(acc, fun)
    end
  
    defp do_reduce(_,       {:halt, acc}, _fun),   do: {:halted, acc}
    defp do_reduce(list,    {:suspend, acc}, fun), do: {:suspended, acc, &do_reduce(list, &1, fun)}
    defp do_reduce([],      {:cont, acc}, _fun),   do: {:done, acc}
    defp do_reduce([h | t], {:cont, acc}, fun),    do: do_reduce(t, fun.(h, acc), fun)
  end

  defimpl Collectable do
    def into(original ) do
      {original, fn
        # Building a higher-order tensor from lower-order tensors.
        tensor = %Tensor{dimensions: dimensions = [cur_dimension| lower_dimensions]}, 
        {:cont, elem = %Tensor{dimensions: elem_dimensions}} 
        when lower_dimensions == elem_dimensions -> 
          new_dimensions = [cur_dimension+1| lower_dimensions]
          new_tensor = %Tensor{tensor | dimensions: new_dimensions, contents: tensor.contents}
          put_in new_tensor, [cur_dimension], elem
        # Inserting values directly into a Vector
        tensor = %Tensor{dimensions: [length]}, {:cont, elem} -> 
          new_length = length+1
          new_contents = put_in(tensor.contents, [length], elem)
          %Tensor{tensor | dimensions: [new_length], contents: new_contents}
        _, {:cont, elem} -> 
          # Other operations not permitted
          raise Tensor.CollectableError, elem
        tensor,  :done -> tensor
        _tensor, :halt -> :ok
      end}
    end
  end

end
