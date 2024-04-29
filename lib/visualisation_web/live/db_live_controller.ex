defmodule VisualisationWeb.DBLiveController do
  use VisualisationWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.live_component module={VisualisationWeb.IncA} id="inc_a" />

    <.live_component module={VisualisationWeb.Test} id="test_db" />

    <%= live_render(@socket, VisualisationWeb.Node, id: "1_1") %>
    """
  end
end

defmodule VisualisationWeb.Node do
  use VisualisationWeb, :live_view

  def mount(_params, _session, socket) do
    :ok = Phoenix.PubSub.subscribe(Visualisation.PubSub, "kvstore")

    ssts =
      Kvstore.SSTList.list(socket.id)
      |> Enum.map(fn file ->
        file
        |> Atom.to_string()
        |> String.split("_")
        |> List.last()
      end)

    {:ok, assign(socket, node_id: socket.id, ssts: ssts)}
  end

  def render(assigns) do
    ~H"""
    <div>
      Node: <%= @node_id %> <br /> SSts:
      <ul>
        <%= for sst <- @ssts do %>
          <li><%= sst %></li>
        <% end %>
      </ul>
    </div>
    """
  end

  def handle_info({:sst_writen, node_id, file_name}, socket) do
    case node_id == socket.id do
      true ->
        {:noreply, assign(socket, ssts: [file_name | socket.assigns.ssts])}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info({:sst_removed, ssts, node_id}, socket) do
    case node_id == socket.id do
      true ->
        {:noreply,
         assign(socket,
           ssts: Enum.reject(socket.assigns.ssts, fn sst -> Enum.member?(ssts, sst) end)
         )}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_info(msg, socket) do
    # dbg(msg)
    {:noreply, socket}
  end
end

defmodule VisualisationWeb.Test do
  use VisualisationWeb, :live_component

  def mount(socket) do
    {:ok,
     assign(
       socket,
       form: %{"keys" => 1032, "incs" => 3},
       test_result: Phoenix.LiveView.AsyncResult.ok("no result yet")
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.simple_form for={@form} phx-submit="do_the_test" phx-target={@myself}>
        <.input field={@form[:keys]} label="keys" name="keys" value={@form["keys"]} />
        <.input field={@form[:incs]} label="increments" name="increments" value={@form["incs"]} />
        <:actions>
          <.button>
            Go
          </.button>
        </:actions>
      </.simple_form>

      <div :if={@test_result.loading}>Processing ...</div>
      <div :if={test_result = @test_result.ok? && @test_result.result}>
        test result: <%= test_result %>
      </div>
    </div>
    """
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

defmodule VisualisationWeb.IncA do
  use VisualisationWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, key: KV.get("a"))}
  end

  def render(assigns) do
    ~H"""
    <div>
      a = "<%= @key %>" <br />
      <.button
        phx-click="inc"
        phx-target={@myself}
        phx-disable-with="Updating..."
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
      >
        Inc a key "a"
      </.button>
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

    {:noreply, assign(socket, key: new_val)}
  end
end
