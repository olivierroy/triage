defmodule TriageWeb.EmailRuleHTML do
  use TriageWeb, :html

  embed_templates "email_rule_html/*"

  attr :form, Phoenix.HTML.Form, required: true
  attr :id, :string, required: true
  attr :action, :string, required: true
  attr :method, :string, default: "post"
  attr :submit_label, :string, required: true

  def email_rule_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      action={@action}
      method="post"
      class="space-y-6 rounded-3xl border border-slate-200 bg-white p-6 shadow-xl shadow-slate-200/70"
    >
      <input :if={@method in ~w(patch put)} type="hidden" name="_method" value={@method} />

      <.input field={@form[:name]} type="text" label="Rule name" placeholder="Skip promos" />

      <.input
        field={@form[:action]}
        type="select"
        label="Action"
        options={[{"Process normally", "process"}, {"Skip entirely", "skip"}]}
      />

      <.input
        field={@form[:archive]}
        type="select"
        label="After processing"
        options={[{"Archive in Gmail", true}, {"Leave in inbox", false}]}
      />

      <.input
        field={@form[:match_senders]}
        type="textarea"
        label="Senders (one per line or comma)"
        rows="3"
        placeholder="promotions@example.com, alerts@service.com"
      />

      <.input
        field={@form[:match_subject_keywords]}
        type="textarea"
        label="Subject keywords"
        rows="3"
        placeholder="invoice, sponsorship, weekly roundup"
      />

      <.input
        field={@form[:match_body_keywords]}
        type="textarea"
        label="Body keywords"
        rows="3"
        placeholder="unsubscribe, product update"
      />

      <div class="flex flex-wrap items-center gap-3">
        <.button phx-disable-with="Saving..." class="bg-sky-600 hover:bg-sky-500">
          {@submit_label}
        </.button>
        <.link
          href={~p"/email_rules"}
          class="text-sm font-semibold text-slate-500 hover:text-slate-900"
        >
          Cancel
        </.link>
      </div>
    </.form>
    """
  end

  def display_list([]), do: "—"

  def display_list(list) when is_list(list) do
    list
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> case do
      "" -> "—"
      value -> value
    end
  end
end
