const RESOLVED_ATTRIBUTE = "data-confirm-resolved";
const DIALOG_ID = "confirm-dialog";

const DIALOG_MARKUP = `
  <div id="${DIALOG_ID}-backdrop" class="bg-neutral/90 fixed inset-0 transition-opacity duration-200"></div>
  <div id="${DIALOG_ID}-wrapper" class="fixed inset-0 overflow-y-auto">
    <div class="flex min-h-full items-center justify-center p-4 sm:p-6">
      <div
        id="${DIALOG_ID}-card"
        role="dialog"
        aria-modal="true"
        aria-labelledby="${DIALOG_ID}-title"
        aria-describedby="${DIALOG_ID}-message"
        class="w-full max-w-md rounded-2xl bg-primary-content shadow-lg ring-1 ring-neutral-700/10 shadow-neutral-700/10 transition-all duration-200"
      >
        <div class="flex items-center gap-4 p-6 pb-0">
          <div class="shrink-0 rounded-full bg-warning/15 p-2 text-warning">
            <span class="hero-exclamation-triangle" aria-hidden="true"></span>
          </div>
          <div class="min-w-0">
            <h2 id="${DIALOG_ID}-title" class="text-lg font-semibold"></h2>
            <p id="${DIALOG_ID}-message" class="mt-1 text-sm opacity-80"></p>
          </div>
        </div>
        <div class="flex justify-end gap-2 p-6">
          <button id="${DIALOG_ID}-cancel" type="button" class="btn">Cancel</button>
          <button id="${DIALOG_ID}-confirm" type="button" class="btn btn-primary">Confirm</button>
        </div>
      </div>
    </div>
  </div>
`;

export function initConfirmDialog() {
  let dialog = null;
  let pendingEl = null;
  let previouslyFocused = null;

  const ensureDialog = () => {
    if (dialog) return dialog;

    dialog = document.createElement("div");
    dialog.id = DIALOG_ID;
    dialog.className = "fixed inset-0 z-50 hidden";
    dialog.innerHTML = DIALOG_MARKUP;
    document.body.appendChild(dialog);

    const backdrop = dialog.querySelector(`#${DIALOG_ID}-backdrop`);
    const wrapper = dialog.querySelector(`#${DIALOG_ID}-wrapper`);
    const cancelBtn = dialog.querySelector(`#${DIALOG_ID}-cancel`);
    const confirmBtn = dialog.querySelector(`#${DIALOG_ID}-confirm`);
    const card = dialog.querySelector(`#${DIALOG_ID}-card`);

    backdrop.addEventListener("click", cancel);
    wrapper.addEventListener("click", (e) => {
      if (!e.target.closest(`#${DIALOG_ID}-card`)) cancel();
    });
    cancelBtn.addEventListener("click", cancel);

    confirmBtn.addEventListener("click", () => {
      const el = pendingEl;
      close();
      if (el) {
        el.setAttribute(RESOLVED_ATTRIBUTE, "");
        el.click();
      }
    });

    dialog.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        cancel();
      } else if (e.key === "Tab") {
        trapFocus(e, [cancelBtn, confirmBtn]);
      }
    });

    return dialog;
  };

  const open = (el) => {
    const root = ensureDialog();
    const title = el.getAttribute("data-confirm-title") || "Please confirm";
    const message = el.getAttribute("data-confirm");
    const confirmLabel = el.getAttribute("data-confirm-label") || "Confirm";
    const danger = el.hasAttribute("data-confirm-danger");

    const titleEl = root.querySelector(`#${DIALOG_ID}-title`);
    const messageEl = root.querySelector(`#${DIALOG_ID}-message`);
    const confirmBtn = root.querySelector(`#${DIALOG_ID}-confirm`);
    const card = root.querySelector(`#${DIALOG_ID}-card`);
    const backdrop = root.querySelector(`#${DIALOG_ID}-backdrop`);

    titleEl.textContent = title;
    messageEl.textContent = message;
    confirmBtn.textContent = confirmLabel;
    confirmBtn.classList.toggle("btn-error", danger);
    confirmBtn.classList.toggle("btn-primary", !danger);

    previouslyFocused = document.activeElement;
    document.body.style.overflow = "hidden";

    card.classList.add("opacity-0", "scale-95");
    backdrop.classList.add("opacity-0");
    root.classList.remove("hidden");
    void root.offsetHeight;

    requestAnimationFrame(() => {
      card.classList.remove("opacity-0", "scale-95");
      backdrop.classList.remove("opacity-0");
    });

    confirmBtn.focus();
  };

  const close = () => {
    if (!dialog || dialog.classList.contains("hidden")) return;

    const card = dialog.querySelector(`#${DIALOG_ID}-card`);
    const backdrop = dialog.querySelector(`#${DIALOG_ID}-backdrop`);

    card.classList.add("opacity-0", "scale-95");
    backdrop.classList.add("opacity-0");

    setTimeout(() => {
      dialog.classList.add("hidden");
      document.body.style.overflow = "";
    }, 200);

    if (previouslyFocused && typeof previouslyFocused.focus === "function") {
      previouslyFocused.focus();
    }
    previouslyFocused = null;
    pendingEl = null;
  };

  const cancel = () => {
    pendingEl = null;
    close();
  };

  const trapFocus = (e, focusables) => {
    const first = focusables[0];
    const last = focusables[focusables.length - 1];

    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };

  document.body.addEventListener(
    "phoenix.link.click",
    (e) => {
      e.stopPropagation();

      const el = e.target;
      const message = el?.getAttribute?.("data-confirm");
      if (!message) return;

      if (el.hasAttribute(RESOLVED_ATTRIBUTE)) {
        el.removeAttribute(RESOLVED_ATTRIBUTE);
        return;
      }

      e.preventDefault();

      if (dialog && !dialog.classList.contains("hidden")) return;

      pendingEl = el;
      open(el);
    },
    false
  );
}