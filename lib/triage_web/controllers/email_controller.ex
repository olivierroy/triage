defmodule TriageWeb.EmailController do
  use TriageWeb, :controller

  alias Triage.Gmail
  alias Triage.Categories

  def index(conn, params) do
    current_scope = conn.assigns[:current_scope]
    category_id = params["category_id"]
    page = String.to_integer(params["page"] || "1")
    page_size = 50
    offset = (page - 1) * page_size

    category = if category_id && category_id != "none", do: Categories.get_category!(current_scope, category_id)

    opts = case category_id do
      "none" -> [category_id: nil]
      id when is_binary(id) -> [category_id: id]
      _ -> []
    end

    total_count = Gmail.count_emails(current_scope, opts)
    emails = Gmail.list_emails(current_scope, opts ++ [limit: page_size, offset: offset])

    render(conn, :index,
      emails: emails,
      category: category,
      category_id: category_id,
      page: page,
      total_pages: ceil(total_count / page_size)
    )
  end

  def delete(conn, %{"id" => id} = params) do
    current_scope = conn.assigns[:current_scope]
    category_id = params["category_id"]
    page = params["page"]

    case Gmail.delete_email(current_scope, id) do
      {:ok, _email} ->
        conn
        |> put_flash(:info, "Email deleted successfully (synced with Gmail)")
        |> redirect(to: ~p"/emails?#{[category_id: category_id, page: page]}")

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to delete email")
        |> redirect(to: ~p"/emails?#{[category_id: category_id, page: page]}")
    end
  end
  def reprocess(conn, %{"id" => id} = params) do
    current_scope = conn.assigns[:current_scope]
    category_id = params["category_id"]
    page = params["page"]

    case Gmail.reprocess_email(current_scope, id) do
      {:ok, _email} ->
        conn
        |> put_flash(:info, "Email reprocessed successfully with AI")
        |> redirect(to: ~p"/emails?#{[category_id: category_id, page: page]}")

      {:error, error} ->
        conn
        |> put_flash(:error, "Failed to reprocess email: #{error}")
        |> redirect(to: ~p"/emails?#{[category_id: category_id, page: page]}")
    end
  end
end
