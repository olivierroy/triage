defmodule TriageWeb.UnsubscribeLive do
  use TriageWeb, :live_view
  on_mount {TriageWeb.UserAuth, :ensure_authenticated}

  alias Triage.Unsubscribes

  @page_size 50

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected_status, nil)
     |> stream(:unsubscribes, [])}
  end

  def handle_params(params, _uri, socket) do
    status = params["status"]
    page = String.to_integer(params["page"] || "1")

    {:noreply,
     socket
     |> assign(:selected_status, status)
     |> assign(:page, page)
     |> fetch_unsubscribes()}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    status_value = if(status == "", do: nil, else: status)

    {:noreply,
     push_patch(socket,
       to: ~p"/unsubscribes?#{[status: status_value]}"
     )}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/unsubscribes?#{[status: socket.assigns.selected_status, page: page]}"
     )}
  end

  defp fetch_unsubscribes(socket) do
    current_scope = socket.assigns.current_scope
    status = socket.assigns.selected_status
    page = socket.assigns.page
    offset = (page - 1) * @page_size

    opts = []
    opts = if status, do: Keyword.put(opts, :status, String.to_atom(status)), else: opts

    all_unsubscribes = Unsubscribes.list_unsubscribes(current_scope, opts)
    total_count = length(all_unsubscribes)
    unsubscribes = Enum.slice(all_unsubscribes, offset, @page_size)

    title =
      case status do
        "success" -> "Successful Unsubscribes"
        "failed" -> "Failed Unsubscribes"
        _ -> "All Unsubscribes"
      end

    socket
    |> assign(:title, title)
    |> assign(:total_pages, max(1, ceil(total_count / @page_size)))
    |> assign(:has_unsubscribes?, not Enum.empty?(unsubscribes))
    |> stream(:unsubscribes, unsubscribes, reset: true)
  end
end
