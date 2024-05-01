defmodule VisualisationWeb.DBLiveController do
  use VisualisationWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-1">
      <button
        id="toggleButton"
        class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-1 px-1 rounded"
      >
        Boring Controlls
      </button>
      <div id="content" class="rounded hidden">
        <div class="flex">
          <div class="flex-1 border border-gray-300">
            <.live_component module={VisualisationWeb.Set} id="set" />
          </div>
          <div class="flex-1 border border-gray-300">
            <.live_component module={VisualisationWeb.Get} id="get" />
          </div>
        </div>
      </div>
    </div>

    <script>
      const button = document.getElementById('toggleButton');
      const content = document.getElementById('content');

      button.onclick = function() {
          content.classList.toggle('hidden');
          button.textContent = content.classList.contains('hidden') ? 'Boring Congrolls' : 'Hide';
      };
    </script>

    <div class="flex">
      <div class="flex-1 border border-gray-300 p-4">
        <.live_component module={VisualisationWeb.Test} id="test_db" />
      </div>
      <div class="flex-1 border border-gray-300 p-4">
        <.live_component module={VisualisationWeb.AddRandom} id="add_random" />
      </div>
    </div>

    <div class="flex">
      <div class="flex-1 border border-gray-300 p-4">
        Node 1
        <div class="flex">
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "1_1") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "1_2") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "1_3") %>
          </div>
        </div>
      </div>
      <div class="flex-1 border border-gray-300 p-4">
        Node 2
        <div class="flex">
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "2_1") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "2_2") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "2_3") %>
          </div>
        </div>
      </div>
      <div class="flex-1 border border-gray-300 p-4">
        Node 3
        <div class="flex">
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "3_1") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "3_2") %>
          </div>
          <div class="flex-1 p-4 border border-gray-300">
            <%= live_render(@socket, VisualisationWeb.Node, id: "3_3") %>
          </div>
        </div>
      </div>
    </div>
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

    {:ok, assign(socket, node_id: socket.id, ssts: ssts, lsm: get_lsm!(socket.id))}
  end

  def render(assigns) do
    ~H"""
    <div>
      id: <%= @node_id %> <br /> SSts:
      <ul class="h-20">
        <%= for sst <- @ssts do %>
          <li><%= sst %></li>
        <% end %>
      </ul>

      <br /> LSM:
      <ul>
        <%= for {level, parts} <- @lsm do %>
          <li>
            <b>Level <%= level %></b>
            <ul>
              <%= for {part, bound} <- parts do %>
                <li>
                  <p>&ensp;<%= part %> | <%= bound %></p>
                </li>
              <% end %>
            </ul>
          </li>
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

  def handle_info({:update_lsm, _, _, node_id}, socket) do
    case node_id == socket.id do
      true ->
        {:noreply, assign(socket, lsm: get_lsm!(node_id))}

      _ ->
        {:noreply, socket}
    end
  end

  defp get_lsm!(node_id) do
    node_id
    |> Kvstore.LSMTree.get_levels()
    |> Enum.map(fn {level, _, _} = x -> {level, Kvstore.LSMLevel.list_parts(x)} end)
  end
end

defmodule VisualisationWeb.AddRandom do
  use VisualisationWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, form: %{"n" => "10"})}
  end

  def render(assigns) do
    ~H"""
    <div>
      Add random key-values
      <.simple_form for={@form} phx-submit="add_random" phx-target={@myself}>
        <.input field={@form[:n]} label="n" name="n" value={@form["n"]} />
        <:actions>
          <.button>
            GO
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("add_random", %{"n" => n}, socket) do
    n
    |> String.to_integer()
    |> KV.add_random_keys()

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
      Increment n keys x times
      <.simple_form for={@form} phx-submit="do_the_test" phx-target={@myself}>
        <.input field={@form[:keys]} label="keys" name="keys" value={@form["keys"]} />
        <.input field={@form[:incs]} label="increments" name="increments" value={@form["incs"]} />
        <:actions>
          <.button>
            GO
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
     socket
     |> assign(:form_test, %{"keys" => keys, "incs" => incs})
     |> assign_async(:test_result, fn ->
       res =
         KV.do_the_test(String.to_integer(keys), String.to_integer(incs))
         |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
         |> Enum.join(", ")
         |> (&"{#{&1}}").()

       {:ok, %{test_result: res}}
     end)}
  end
end

defmodule VisualisationWeb.Get do
  use VisualisationWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, form: %{"key" => "zzzzzzzzz"}, res: nil)}
  end

  def render(assigns) do
    ~H"""
    <div>
      Get value for key
      <.simple_form for={@form} phx-submit="get" phx-target={@myself}>
        <.input field={@form["key"]} label="key" name="key" value={@form["key"]} />
        <:actions>
          <.button>
            Get
          </.button>
        </:actions>
      </.simple_form>
      <div :if={@res}>
        <%= @res %>
      </div>
    </div>
    """
  end

  def handle_event("get", %{"key" => key}, socket) do
    res = KV.get(key)
    {:noreply, assign(socket, form: %{"key" => key}, res: res)}
  end
end

defmodule VisualisationWeb.Set do
  use VisualisationWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, form: %{"key" => "zzzzzzzzz", "value" => "34"})}
  end

  def render(assigns) do
    ~H"""
    <div>
      Set value for key
      <.simple_form for={@form} phx-submit="set" phx-target={@myself}>
        <.input field={@form["key"]} label="key" name="key" value={@form["key"]} />
        <.input field={@form["value"]} label="value" name="value" value={@form["value"]} />
        <:actions>
          <.button>
            Set
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("set", %{"key" => key, "value" => value}, socket) do
    KV.set(key, value)
    {:noreply, assign(socket, form: %{"key" => key, "value" => value})}
  end
end
