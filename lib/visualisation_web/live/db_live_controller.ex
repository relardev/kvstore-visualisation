defmodule VisualisationWeb.DBLiveController do
  use VisualisationWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Visualisation.PubSub, "kvstore")
    end

    {:ok,
     assign(socket,
       a: "",
       form: %{"keys" => "", "incs" => ""},
       test_result: Phoenix.LiveView.AsyncResult.ok("no result yet")
     )}
  end

  def render(assigns) do
    ~H"""
    a = "<%= @a %>" <br />
    <.button
      phx-click="inc"
      phx-disable-with="Updating..."
      class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
    >
      Inc a key "a"
    </.button>

    <.simple_form for={@form} phx-submit="do_the_test">
      <.input field={@form[:keys]} label="keys" name="keys" value="1000" />
      <.input field={@form[:incs]} label="increments" name="increments" value="3" />
      <:actions>
        <.button>Go</.button>
      </:actions>
    </.simple_form>

    <div :if={@test_result.loading}>Processing ...</div>
    <div :if={test_result = @test_result.ok? && @test_result.result}>
      test result: <%= test_result %>
    </div>
    """
  end

  def handle_event("inc", _, socket) do
    new_val =
      case KV.get("a") do
        nil ->
          KV.set("a", "1")
          "1"

        v ->
          v
          |> String.to_integer()
          |> Kernel.+(1)
          |> Integer.to_string()
          |> tap(&KV.set("a", &1))
      end

    {:noreply, assign(socket, a: new_val)}
  end

  def handle_event("do_the_test", %{"keys" => keys, "increments" => incs}, socket) do
    {:noreply,
     assign_async(socket, :test_result, fn ->
       res =
         KV.do_the_test(String.to_integer(keys), String.to_integer(incs))
         |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
         |> Enum.join(", ")
         |> (&"{#{&1}}").()

       {:ok, %{test_result: res}}
     end)}
  end
end
