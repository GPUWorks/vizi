defmodule Vizi.Canvas.Transform do
  @moduledoc """
  The functions in this module do not transform the view directly.
  They return a matrix that can be applied to the view by calling
  `Vizi.Canvas.transform/2`.
  """

  alias Vizi.NIF

  @type t :: <<>>

  @doc """
  Sets the transform to the identity matrix.
  """
  defdelegate identity(), to: NIF, as: :transform_identity

  @doc """
  Sets the transform to a translation matrix.
  """
  defdelegate translate(x, y), to: NIF, as: :transform_translate

  @doc """
  Sets the transform to a scale matrix.
  """
  defdelegate scale(x, y), to: NIF, as: :transform_scale

  @doc """
  Sets the transform to a rotate matrix. Angle is specified in radians.
  """
  defdelegate rotate(angle), to: NIF, as: :transform_rotate

  @doc """
  Sets the transform to a skew-x matrix. Angle is specified in radians.
  """
  defdelegate skew_x(angle), to: NIF, as: :transform_skew_x

  @doc """
  Sets the transform to a skew-y matrix. Angle is specified in radians.
  """
  defdelegate skew_y(angle), to: NIF, as: :transform_skew_y

  @doc """
  Sets the transform to the result of multiplication of two transforms, of A = A*B.
  """
  defdelegate multiply(a, b), to: NIF, as: :transform_multiply

  @doc """
  Sets the transform to the result of multiplication of two transforms, of A = B*A.
  """
  defdelegate premultiply(a, b), to: NIF, as: :transform_premultiply

  @doc """
  Returns the inverse of the given transform.
  """
  defdelegate inverse(matrix), to: NIF, as: :transform_inverse

  @doc """
  Transform a point by given transform.
  """
  defdelegate point(matrix, x, y), to: NIF, as: :transform_point

  @doc """
  Converts a matrix resource to a list.
  """
  defdelegate matrix_to_list(matrix), to: NIF

  @doc """
  Converts a list with at least 6 values to matrix resource.
  """
  defdelegate list_to_matrix(list), to: NIF
end