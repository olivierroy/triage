defmodule TriageWeb.EmailLive do
  use TriageWeb, :live_view
  on_mount {TriageWeb.UserAuth, :ensure_authenticated}

  alias Triage.Gmail
  alias Triage.Categories

  @page_size 50

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected_email, nil)
     |> stream(:emails, [])}
  end

  def handle_params(params, _uri, socket) do
    category_id = params["category_id"]
    page = String.to_integer(params["page"] || "1")

    {:noreply,
     socket
     |> assign(:category_id, category_id)
     |> assign(:page, page)
     |> fetch_emails()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]
    email = Gmail.get_email!(current_scope, id)

    case Gmail.delete_email(current_scope, id) do
      {:ok, _email} ->
        socket =
          if socket.assigns.selected_email && socket.assigns.selected_email.id == id do
            assign(socket, :selected_email, nil)
          else
            socket
          end

        {:noreply,
         socket
         |> put_flash(:info, "Email deleted successfully")
         |> stream_delete(:emails, email)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete email from Gmail")}
    end
  end

  def handle_event("reprocess", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]

    case Gmail.reprocess_email(current_scope, id) do
      {:ok, _email} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email reprocessed successfully with AI")
         |> fetch_emails()}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to reprocess email: #{error}")}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/emails?#{[category_id: socket.assigns.category_id, page: page]}")}
  end

  def handle_event("view_email", %{"id" => id}, socket) do
    current_scope = socket.assigns[:current_scope]
    email = Gmail.get_email!(current_scope, id)
    {:noreply, assign(socket, :selected_email, email)}
  end

  def handle_event("close_email", _, socket) do
    {:noreply, assign(socket, :selected_email, nil)}
  end

  defp fetch_emails(socket) do
    current_scope = socket.assigns[:current_scope]
    category_id = socket.assigns[:category_id]
    page = socket.assigns[:page]
    offset = (page - 1) * @page_size

    category =
      if category_id && category_id != "none",
        do: Categories.get_category!(current_scope, category_id)

    opts =
      case category_id do
        "none" -> [category_id: nil]
        id when is_binary(id) -> [category_id: id]
        _ -> []
      end

    total_count = Gmail.count_emails(current_scope, opts)
    emails = Gmail.list_emails(current_scope, opts ++ [limit: @page_size, offset: offset])

    title =
      cond do
        category -> "Emails in #{category.name}"
        category_id == "none" -> "Uncategorized Emails"
        true -> "Your Email Inbox"
      end

    socket
    |> assign(:category, category)
    |> assign(:title, title)
    |> assign(:total_pages, max(1, ceil(total_count / @page_size)))
    |> assign(:has_emails?, not Enum.empty?(emails))
    |> stream(:emails, emails, reset: true)
  end
end
