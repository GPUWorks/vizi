defmodule Vizi.Events do
  @moduledoc false

  defmodule Button do
    @moduledoc false
    defstruct [:context, :type, :time, :x, :y, :abs_x, :abs_y, :x_root, :y_root, :state, :button]
  end

  defmodule Configure do
    @moduledoc false
    defstruct [:context, :type, :x, :y, :width, :height]
  end

  defmodule Expose do
    @moduledoc false
    defstruct [:context, :type, :x, :y, :width, :height, :count]
  end

  defmodule Close do
    @moduledoc false
    defstruct [:context, :type]
  end

  defmodule Key do
    @moduledoc false
    defstruct [:context, :type, :time, :abs_x, :abs_y, :x, :y, :x_root, :y_root, :state, :keycode, :character, :special, :utf8, :filter]
  end

  defmodule Crossing do
    @moduledoc false
    defstruct [:context, :type, :time, :abs_x, :abs_y, :x, :y, :x_root, :y_root, :state, :mode]
  end

  defmodule Motion do
    @moduledoc false
    defstruct [:context, :type, :time, :abs_x, :abs_y, :x, :y, :x_root, :y_root, :state, :is_hint, :focus]
  end

  defmodule Scroll do
    @moduledoc false
    defstruct [:context, :type, :time, :abs_x, :abs_y, :x, :y, :x_root, :y_root, :state, :dx, :dy]
  end

  defmodule Focus do
    @moduledoc false
    defstruct [:context, :type, :grab]
  end

  defmodule Draw do
    @moduledoc false
    defstruct [:context, :type, :time]
  end

  defmodule Update do
    @moduledoc false
    defstruct [:context, :type, :time]
  end

  defmodule Custom do
    @moduledoc false
    defstruct [:context, :type, :params, :time]
  end
end




