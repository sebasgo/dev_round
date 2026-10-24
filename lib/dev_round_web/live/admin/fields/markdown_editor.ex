defmodule DevRoundWeb.Admin.Fields.MarkdownEditor do
  @config_schema [
    rows: [
      doc: "Number of visible text lines for the editor.",
      type: :non_neg_integer,
      default: 20
    ],
    debounce: [
      doc: "Timeout value (in milliseconds), \"blur\" or function that receives the assigns.",
      type: {:or, [:pos_integer, :string, {:fun, 1}]},
      default: 300
    ],
    placeholder: [
      doc: "Placeholder value or function that receives the assigns.",
      type: {:or, [:string, {:fun, 1}]}
    ]
  ]

  @moduledoc """
  A markdown editor field with a live preview.

  The backing form control is a plain `<textarea>`, so form submission, changeset
  validation and `readonly` handling are unchanged. On top of it this field adds:

    * a `markdown` / `split` / `preview` view-mode switch,
    * a Prism-highlighted overlay of the editor content,
    * a server-rendered preview that uses `DevRound.Markdown.to_html/1`, i.e. the
      same renderer as the public event pages.

  The client-side behaviour (mode switch, syntax highlighting and synced
  scrolling of editor and preview) is implemented in the `MarkdownEditor` JS
  hook.

  ## Field-specific options

  See `Backpex.Field` for general field options.

  #{NimbleOptions.docs(@config_schema)}
  """

  use Backpex.Field, config_schema: @config_schema

  @impl Backpex.Field
  defdelegate render_value(assigns), to: Backpex.Fields.Textarea

  @impl Phoenix.LiveComponent
  def update(%{type: :form} = assigns, socket) do
    field = assigns.form[assigns.name]

    socket
    |> assign(assigns)
    |> assign(:editor_id, "markdown-editor-#{field.id}")
    |> assign(:storage_key, storage_key(assigns.name, assigns.live_resource))
    |> assign(:preview_html, DevRound.Markdown.to_html(field.value))
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl Backpex.Field
  def render_form(%{readonly: true} = assigns) do
    ~H"""
    <div>
      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label as="span" text={@field_options[:label]} />
        </:label>
        <article class="prose max-w-none">
          {@preview_html}
        </article>
      </Layout.field_container>
    </div>
    """
  end

  def render_form(assigns) do
    field = assigns.form[assigns.name]
    help_text = Backpex.Field.help_text(assigns.field_options, assigns)

    assigns =
      assigns
      |> assign(:help_text, help_text)
      |> assign(:input_id, field.id)
      |> assign(:input_name, field.name)
      |> assign(:input_value, field.value)
      |> assign(:input_errors, field_errors(field, assigns))
      |> assign(:placeholder, placeholder(assigns))

    ~H"""
    <div>
      <style>
        .markdown-editor-resize {
          height: calc(var(--md-rows, 15) * 1.4rem + 1.5rem);
          min-height: 5rem;
          resize: vertical;
          overflow: hidden;
        }

        .markdown-editor-panes {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 1rem;
          height: 100%;
          min-height: 0;
        }

        .markdown-editor[data-mode="markdown"] .markdown-editor-panes,
        .markdown-editor[data-mode="preview"] .markdown-editor-panes {
          grid-template-columns: 1fr;
        }

        .markdown-editor[data-mode="markdown"] .markdown-editor-pane[data-pane="preview"],
        .markdown-editor[data-mode="preview"] .markdown-editor-pane[data-pane="markdown"] {
          display: none;
        }

        .markdown-editor [data-md-mode][aria-pressed="true"] {
          background-color: var(--color-primary);
          border-color: var(--color-primary);
          color: var(--color-primary-content);
        }

        .markdown-editor-pane {
          position: relative;
          min-width: 0;
          min-height: 0;
          overflow: hidden;
          border: var(--border, 1px) solid var(--color-base-300);
          border-radius: var(--radius-box, 0.5rem);
          background-color: var(--color-base-100);
        }

        .markdown-editor-highlight {
          position: absolute;
          inset: 0;
          overflow: hidden;
          pointer-events: none;
        }

        .markdown-editor-pre,
        .markdown-editor-textarea {
          box-sizing: border-box;
          margin: 0;
          padding: 0.75rem 1rem;
          font-family: var(--font-mono);
          font-size: 0.875rem;
          line-height: 1.6;
          tab-size: 2;
          white-space: pre-wrap;
          overflow-wrap: break-word;
          word-break: break-word;
        }

        .markdown-editor-pre {
          height: 100%;
          overflow: hidden;
          color: var(--color-base-content);
          background-color: transparent;
        }

        .markdown-editor-pre code {
          display: block;
          padding: 0;
          font: inherit;
          tab-size: inherit;
          white-space: inherit;
          word-break: inherit;
          background: none;
        }

        .markdown-editor-textarea {
          position: relative;
          z-index: 1;
          display: block;
          width: 100%;
          height: 100%;
          resize: none;
          overflow-y: auto;
          border: 0;
          outline: none;
          background-color: transparent;
          color: transparent;
          caret-color: var(--color-base-content);
        }

        .markdown-editor-textarea::placeholder {
          color: var(--color-base-content);
          opacity: 0.4;
        }

        .markdown-editor-textarea::selection {
          color: transparent;
          background-color: color-mix(in oklab, var(--color-primary) 45%, transparent);
        }

        .markdown-editor-textarea-error {
          box-shadow: inset 0 0 0 2px var(--color-error);
        }

        .markdown-editor-preview {
          height: 100%;
          overflow-y: auto;
          padding: 0.75rem 1rem;
        }
      </style>

      <Layout.field_container>
        <:label :if={not @hide_label} align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label for={@input_id} text={@field_options[:label]} />
        </:label>

        <div
          id={@editor_id}
          phx-hook=".MarkdownEditor"
          class="markdown-editor"
          data-md-storage-key={@storage_key}
        >
          <div class="mb-2 flex justify-end">
            <div
              class="join"
              role="group"
              aria-label="Markdown editor view mode"
            >
              <button type="button" class="btn btn-xs join-item" data-md-mode="markdown">
                Markdown
              </button>
              <button type="button" class="btn btn-xs join-item" data-md-mode="split">
                Split
              </button>
              <button type="button" class="btn btn-xs join-item" data-md-mode="preview">
                Preview
              </button>
            </div>
          </div>

          <div class="markdown-editor-resize" style={"--md-rows: #{@field_options[:rows]}"}>
            <div class="markdown-editor-panes">
              <div class="markdown-editor-pane" data-pane="markdown">
                <div
                  id={"#{@editor_id}-highlight"}
                  phx-update="ignore"
                  class="markdown-editor-highlight"
                  aria-hidden="true"
                >
                  <pre class="markdown-editor-pre"><code class="language-markdown"></code></pre>
                </div>
                <textarea
                  id={@input_id}
                  name={@input_name}
                  class={[
                    "markdown-editor-textarea",
                    @input_errors != [] && "markdown-editor-textarea-error"
                  ]}
                  rows={@field_options[:rows]}
                  placeholder={@placeholder}
                  phx-debounce={Backpex.Field.debounce(@field_options, assigns)}
                  aria-labelledby={Map.get(assigns, :aria_labelledby)}
                >{PhoenixForm.normalize_value("textarea", @input_value)}</textarea>
              </div>

              <div class="markdown-editor-pane" data-pane="preview">
                <div class="markdown-editor-preview" data-md-preview>
                  <article class="prose max-w-none">{@preview_html}</article>
                </div>
              </div>
            </div>
          </div>

          <BackpexForm.error :for={msg <- @input_errors}>{msg}</BackpexForm.error>
          <BackpexForm.help_text :if={@help_text}>{@help_text}</BackpexForm.help_text>
        </div>
      </Layout.field_container>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".MarkdownEditor">
        import Prism from "prismjs"

        const MODES = ["markdown", "split", "preview"]
        const STORAGE_KEY_PREFIX = "devround:markdown-editor-mode:"

        // Drives the markdown editor field:
        //
        //   * the markdown / split / preview view-mode switch,
        //   * the Prism-highlighted overlay behind the textarea,
        //   * proportional scroll syncing between the editor and the preview.
        //
        // Only attributes that the server never renders (`data-mode`, `aria-pressed`)
        // are mutated on server-owned nodes, so LiveView patches do not clobber the
        // client-side state.
        export default {
          mounted() {
            this.textarea = this.el.querySelector(".markdown-editor-textarea")
            this.highlight = this.el.querySelector(".markdown-editor-highlight code")
            this.overlay = this.el.querySelector(".markdown-editor-pre")
            this.preview = this.el.querySelector("[data-md-preview]")
            this.modeButtons = Array.from(this.el.querySelectorAll("[data-md-mode]"))

            if (!this.textarea || !this.preview) return

            this.modeButtons.forEach((button) => {
              button.addEventListener("click", () => this.setMode(button.dataset.mdMode))
            })

            this.textarea.addEventListener("input", () => {
              this.renderHighlight()
              this.syncOverlayScroll()
              this.syncScroll(this.textarea, this.preview)
            })
            this.textarea.addEventListener("scroll", () => {
              this.syncOverlayScroll()
              this.syncScroll(this.textarea, this.preview)
            })
            this.preview.addEventListener("scroll", () => {
              this.syncScroll(this.preview, this.textarea)
            })

            this.onResize = () => this.alignOverlay()
            window.addEventListener("resize", this.onResize)

            // The textarea's width changes when it starts/stops showing a scrollbar
            // (e.g. after a manual resize), so keep the overlay in sync.
            if (typeof ResizeObserver !== "undefined") {
              this.resizeObserver = new ResizeObserver(() => this.alignOverlay())
              this.resizeObserver.observe(this.textarea)
            }

            this.applyMode(this.storedMode())
            this.renderHighlight()
          },

          // Remember the scroll positions so they survive the DOM patch triggered by a
          // debounced server-side preview update.
          beforeUpdate() {
            if (this.preview) this.savedPreviewScrollTop = this.preview.scrollTop
            if (this.textarea) this.savedTextareaScrollTop = this.textarea.scrollTop
          },

          updated() {
            if (!this.textarea || !this.preview) return

            // The server may have patched the textarea value and the preview content.
            this.renderHighlight()

            if (this.savedTextareaScrollTop != null) {
              this.textarea.scrollTop = this.savedTextareaScrollTop
            }

            this.syncOverlayScroll()

            if (this.savedPreviewScrollTop != null) {
              this.preview.scrollTop = this.savedPreviewScrollTop
            }

            this.applyMode(this.currentMode())
          },

          destroyed() {
            if (this.onResize) window.removeEventListener("resize", this.onResize)
            if (this.resizeObserver) this.resizeObserver.disconnect()
          },

          storedMode() {
            try {
              const stored = window.localStorage.getItem(this.storageKey())
              return MODES.includes(stored) ? stored : "split"
            } catch (_error) {
              return "split"
            }
          },

          currentMode() {
            return this.el.dataset.mode || "split"
          },

          // The view mode is scoped to the resource and field name the server put on the
          // element, so separate editors (e.g. teaser and body) remember their own mode.
          storageKey() {
            return this.el.dataset.mdStorageKey || `${STORAGE_KEY_PREFIX}default`
          },

          setMode(mode) {
            if (!MODES.includes(mode)) mode = "split"

            try {
              window.localStorage.setItem(this.storageKey(), mode)
            } catch (_error) {
              // Ignore storage errors (e.g. private browsing).
            }

            this.applyMode(mode)

            if (mode === "split") {
              this.syncScroll(this.textarea, this.preview)
            }
          },

          applyMode(mode) {
            this.el.dataset.mode = mode

            this.modeButtons.forEach((button) => {
              button.setAttribute("aria-pressed", String(button.dataset.mdMode === mode))
            })

            this.alignOverlay()
          },

          renderHighlight() {
            if (!this.highlight) return

            // An empty textarea still occupies one line, and a trailing newline renders
            // an extra (caret) line, while `white-space: pre-wrap` collapses a trailing
            // newline and an empty `<code>` has no line at all. Appending a zero-width
            // space keeps the overlay's line count (and thus scroll height) in sync with
            // the textarea, so it does not drift by one line when scrolled to the bottom.
            this.highlight.textContent = `${this.textarea.value}\u200b`
            Prism.highlightElement(this.highlight)
            this.alignOverlay()
          },

          // Match the overlay width to the textarea's client width so both wrap
          // identically, even when the textarea shows a scrollbar.
          alignOverlay() {
            if (!this.overlay || !this.textarea) return

            this.overlay.style.width = `${this.textarea.clientWidth}px`
          },

          syncOverlayScroll() {
            if (!this.overlay) return

            this.overlay.scrollTop = this.textarea.scrollTop
          },

          syncScroll(source, target) {
            if (!target || this.el.dataset.mode !== "split") return

            const sourceMax = source.scrollHeight - source.clientHeight
            const targetMax = target.scrollHeight - target.clientHeight
            const ratio = sourceMax > 0 ? source.scrollTop / sourceMax : 0
            const next = ratio * targetMax

            // Proportional mapping is its own inverse, so a programmatic scroll that
            // maps back to (nearly) the current position is a no-op. This prevents
            // the two scroll listeners from feeding each other.
            if (Math.abs(target.scrollTop - next) < 1) return

            target.scrollTop = next
          },
        }
      </script>
    </div>
    """
  end

  defp field_errors(field, assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    BackpexForm.translate_form_errors(
      errors,
      Backpex.Field.translate_error_fun(assigns.field_options, assigns)
    )
  end

  defp placeholder(%{field_options: %{placeholder: placeholder}} = assigns)
       when is_function(placeholder, 1) do
    placeholder.(assigns)
  end

  defp placeholder(%{field_options: %{placeholder: placeholder}}) when is_binary(placeholder) do
    placeholder
  end

  defp placeholder(_assigns), do: nil

  # localStorage key for the view mode, scoped to resource + field so separate
  # instances (e.g. teaser and body) do not affect each other.
  defp storage_key(name, resource) when is_atom(name) do
    storage_key(Atom.to_string(name), resource)
  end

  defp storage_key(name, resource) do
    "devround:markdown-editor-mode:#{inspect(resource)}:#{name}"
  end
end
