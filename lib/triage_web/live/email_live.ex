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
     |> assign(:selected_ids, MapSet.new())
     |> stream(:emails, [])}
  end

  def handle_params(params, _uri, socket) do
    category_id = params["category_id"]
    page = String.to_integer(params["page"] || "1")

    {:noreply,
     socket
     |> assign(:category_id, category_id)
     |> assign(:page, page)
     |> assign(:selected_ids, MapSet.new())
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

  def handle_event("toggle_selection", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    new_selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  def handle_event("toggle_all", _params, socket) do
    current_page_ids = socket.assigns.current_page_ids
    selected_ids = socket.assigns.selected_ids

    # If all items on current page are already selected, then deselect all.
    # Otherwise, select everything on current page.
    all_on_page_selected? = Enum.all?(current_page_ids, &MapSet.member?(selected_ids, &1))

    new_selected_ids =
      if all_on_page_selected? do
        # Remove current page IDs from selection
        Enum.reduce(current_page_ids, selected_ids, fn id, acc -> MapSet.delete(acc, id) end)
      else
        # Add current page IDs to selection
        Enum.reduce(current_page_ids, selected_ids, fn id, acc -> MapSet.put(acc, id) end)
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  def handle_event("bulk_delete", _, socket) do
    current_scope = socket.assigns[:current_scope]
    ids = MapSet.to_list(socket.assigns.selected_ids)

    if Enum.empty?(ids) do
      {:noreply, socket}
    else
      # Perform deletion
      results = Enum.map(ids, &Gmail.delete_email(current_scope, &1))

      {successes, failures} =
        Enum.reduce(results, {0, 0}, fn
          {:ok, _}, {s, f} -> {s + 1, f}
          {:error, _}, {s, f} -> {s, f + 1}
        end)

      socket =
        socket
        |> assign(:selected_ids, MapSet.new())
        |> put_flash(
          :info,
          "Deleted #{successes} emails. #{if failures > 0, do: "Failed to delete #{failures} emails.", else: ""}"
        )
        |> fetch_emails()

      {:noreply, socket}
    end
  end

  def handle_event("bulk_unsubscribe", _, socket) do
    {:noreply, put_flash(socket, :error, "Bulk unsubscribe is not yet implemented.")}
  end

  def handle_event("unsubscribe", %{"id" => _id}, socket) do
    {:noreply, put_flash(socket, :error, "Unsubscribe is not yet implemented.")}
  end

  defp fetch_emails(socket) do
    current_scope = socket.assigns[:current_scope]
    category_id = socket.assigns[:category_id]
    page = socket.assigns[:page]
    offset = (page - 1) * @page_size

    category =
      if category_id not in [nil, "", "none"],
        do: Categories.get_category!(current_scope, category_id)

    opts =
      case category_id do
        "none" -> [category_id: nil]
        id when is_binary(id) and id != "" -> [category_id: id]
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
    |> assign(:current_page_ids, Enum.map(emails, &to_string(&1.id)))
    |> stream(:emails, emails, reset: true)
  end
end
