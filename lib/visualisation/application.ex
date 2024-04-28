defmodule Visualisation.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VisualisationWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:visualisation, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Visualisation.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Visualisation.Finch},
      # Start a worker by calling: Visualisation.Worker.start_link(arg)
      # {Visualisation.Worker, arg},
      # Start to serve requests, typically the last entry
      VisualisationWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Visualisation.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VisualisationWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
