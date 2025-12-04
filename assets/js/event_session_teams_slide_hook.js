const EventSessionTeamsSlideHook = {
  mounted() {
    this.setUpLayout();
  },

  updated() {
    this.setUpLayout();
  },

  setUpLayout() {
    this.grid = document.getElementById("event-teams-grid");
    this.teams = this.grid.querySelectorAll(":scope > div");
    this.teamHeights = this.measureHeights(this.teams);

    // arrange teams in a square matrix layout where the last row may have empty spots
    // failing this, use one more row than columns
    // this.cols * (cols + 1) < this.teams.length <= cols ** 2
    this.cols = Math.ceil(-.5 + Math.sqrt(.25 + this.teams.length))

    this.updateLayout();
    this.revealGrid();
    this.setupResizeHandler();
  },

  updateLayout() {
    this.setGridZoom(this.cols, this.calcZoomFactor(this.cols))
  },

  measureHeight(el) {
    return el.getBoundingClientRect().height;
  },

  measureHeights(els) {
    return Array.from(els).map(el => el.getBoundingClientRect().height)
  },

  calcZoomFactor(cols) {
    const padding = 0.015 * this.measureHeight(this.el);
    let availableHeight = Math.floor(this.measureHeight(this.el) * .9 - padding)
    let totalHeight = 0.;
    let rows = 0;
    for (let row = 0, i = 0; i < this.teams.length; row++, i += cols) {
      let rowHeight = Math.max(...this.teamHeights.slice(i, i + cols));
      totalHeight += rowHeight;
      availableHeight -= padding;
      rows++;
    }
    availableHeight -= availableHeight % rows;
    return availableHeight / totalHeight;
  },

  setGridZoom(cols, factor) {
    this.grid.style.gridTemplateColumns = `repeat(${cols}, minmax(0, 1fr))`;
    for (let el of this.teams) {
      el.style.zoom = factor;
    }
  },

  revealGrid() {
    for (let el of this.teams) {
      el.classList.remove("invisible");
    }
  },

  setupResizeHandler() {
    const resizeObserver = new ResizeObserver(() => {
      this.updateLayout();
    });

    resizeObserver.observe(this.grid)
  },
}

export {EventSessionTeamsSlideHook}
