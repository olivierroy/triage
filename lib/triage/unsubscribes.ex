defmodule Triage.Unsubscribes do
  @moduledoc """
  Context module for managing unsubscribe attempts.
  """

  import Ecto.Query, warn: false
  alias Triage.Accounts.Scope
  alias Triage.Repo
  alias Triage.Unsubscribes.Unsubscribe

  def create_unsubscribe_attempt(%Scope{user: %{id: user_id}}, attrs) do
    %Unsubscribe{}
    |> Unsubscribe.changeset(
      Map.merge(attrs, %{
        user_id: user_id,
        attempted_at: DateTime.utc_now()
      })
    )
    |> Repo.insert()
  end

  def get_unsubscribe!(%Scope{user: %{id: user_id}}, id) do
    Repo.get_by!(Unsubscribe, id: id, user_id: user_id) |> Repo.preload([:user])
  end

  def list_unsubscribes(%Scope{user: %{id: user_id}}, opts \\ []) do
    status = Keyword.get(opts, :status)

    query =
      Unsubscribe
      |> where([u], u.user_id == ^user_id)

    query =
      if status do
        where(query, [u], u.status == ^status)
      else
        query
      end

    query
    |> order_by([u], desc: u.inserted_at)
    |> Repo.all()
  end

  def update_unsubscribe_status(%Unsubscribe{} = unsubscribe, attrs) do
    attrs =
      if attrs[:completed_at] == nil and attrs[:status] in [:success, :failed] do
        Map.put(attrs, :completed_at, DateTime.utc_now())
      else
        attrs
      end

    unsubscribe
    |> Unsubscribe.changeset(attrs)
    |> Repo.update()
  end
end
