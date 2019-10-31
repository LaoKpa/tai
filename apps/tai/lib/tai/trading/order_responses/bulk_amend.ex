defmodule Tai.Trading.OrderResponses.BulkAmend do
  @moduledoc """
  Return from venue adapters when amending orders in bulk
  """
  alias Tai.Trading.OrderResponses.Amend

  @type t :: %Tai.Trading.OrderResponses.BulkAmend{
          orders: [Amend.t()]
        }

  @enforce_keys ~w(orders)a
  defstruct ~w(orders)a
end
