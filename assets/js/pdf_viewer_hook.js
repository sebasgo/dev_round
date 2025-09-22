import * as pdfjsLib from 'pdfjs-dist';

// Set up PDF.js worker - Phoenix will serve this from assets
pdfjsLib.GlobalWorkerOptions.workerSrc = '/assets/pdf.worker.min.js';

const PDFViewer = {
  mounted() {
    const pdfUrl = this.el.dataset.pdfUrl;
    const pdfPageNumber = parseInt(this.el.dataset.pdfPageNumber);

    this.currentPage = pdfPageNumber;
    this.pageCount = 0;
    this.pdfDoc = null;
    this.renderedPages = new Map();

    this.loadPDF(pdfUrl);
    this.setupControls();
    this.setupResizeHandler();

    this.handleEvent("pdf_viewer_page_turn", (payload) => {
      this.currentPage = payload.pageNumber;
      this.goToPage(this.currentPage);
    })
  },

  loadPDF(url) {
    const loadingTask = pdfjsLib.getDocument(url);

    loadingTask.promise.then((pdf) => {
      this.pdfDoc = pdf;
      this.pageCount = pdf.numPages;

      // Update total pages
      const totalPagesEl = document.getElementById('total-pages');
      if (totalPagesEl) {
        totalPagesEl.textContent = pdf.numPages;
      }

      this.goToPage(this.currentPage);

    }).catch((error) => {
      console.error('Error loading PDF:', error);
      this.pushEventTo(this.el, 'pdf_error', { error: error.message });
    });
  },

  async renderPage(pageNum) {
    if (this.renderedPages.has(pageNum)) {
      return this.renderedPages.get(pageNum)
    }

    console.log("Starting to render page " + pageNum)

    const page = await this.pdfDoc.getPage(pageNum);

    let container = document.getElementById('pdf-canvas-container');
    let canvas = document.createElement('canvas')

    const referenceViewport = page.getViewport({ scale: 1 });
    const scale = container.clientWidth / referenceViewport.width;
    const viewport = page.getViewport({ scale: scale });

    const context = canvas.getContext('2d');
    canvas.height = viewport.height;
    canvas.width = viewport.width;

    // Render PDF page into canvas context
    const renderContext = {
      canvasContext: context,
      viewport: viewport
    };

    await page.render(renderContext).promise;
    this.renderedPages.set(pageNum, canvas)
    console.log("Finished rendering page " + pageNum)
    return canvas
  },

  async goToPage(pageNum) {
    const pageCanvas = await this.renderPage(pageNum)

    // Display page
    const displayCanvas = document.getElementById('pdf-canvas');
    const ctx = displayCanvas.getContext('2d');
    displayCanvas.width = pageCanvas.width;
    displayCanvas.height = pageCanvas.height;
    ctx.drawImage(pageCanvas, 0, 0);

    // Remove placeholder
    const placeholderEl = document.getElementById('pdf-placeholder');
    if (placeholderEl) {
      placeholderEl.remove();
    }

    // Update current page display
    const currentPageEl = document.getElementById('current-page');
    if (currentPageEl) {
      currentPageEl.textContent = pageNum;
    }

    // Pre-render adjacent pages
    if (pageNum < this.pageCount) {
      this.renderPage(pageNum + 1);
    }

    if (pageNum > 1) {
      this.renderPage(pageNum - 1);
    }
},

  goToNextPage() {
    if (this.pdfDoc && this.currentPage < this.pdfDoc.numPages) {
      this.currentPage++;
      this.goToPage(this.currentPage);
      this.pushEventTo(this.el, 'pdf_page_turn', { page_number: this.currentPage })
    }
  },

  goToPrevPage() {
    if (this.pdfDoc && this.currentPage > 1) {
      this.currentPage--;
      this.goToPage(this.currentPage);
      this.pushEventTo(this.el, 'pdf_page_turn', { page_number: this.currentPage })
    }
  },

  setupControls() {
    // Previous page button
    const prevBtn = document.getElementById('prev-page');
    if (prevBtn) {
      prevBtn.addEventListener('click', () => {
        this.goToPrevPage();
      });
    }

    // Next page button
    const nextBtn = document.getElementById('next-page');
    if (nextBtn) {
      nextBtn.addEventListener('click', () => {
        this.goToNextPage();
      });
    }

    // Keyboard navigation
    this.keydownHandler = (e) => {
      if (!this.pdfDoc) return;

      switch(e.key) {
        case 'ArrowLeft':
        case 'ArrowUp':
          this.goToPrevPage();
          e.preventDefault();
          break;
        case 'ArrowRight':
        case 'ArrowDown':
          this.goToNextPage();
          e.preventDefault();
          break;
      }
    };

    document.addEventListener('keydown', this.keydownHandler);
  },

  setupResizeHandler() {
    const containerEl =  document.getElementById('pdf-canvas-container')
    var lastWidth = containerEl.clientWidth;

    const resizeObserver = new ResizeObserver((entries) => {
      const width = containerEl.clientWidth;
      if (this.pdfDoc && width != lastWidth) {
        lastWidth = width;
        this.renderedPages.clear();
        this.goToPage(this.currentPage);
      }
    });

    resizeObserver.observe(containerEl)
  },

  destroyed() {
    // Suppress navigation and resize events
    this.pdfDoc = null;

    // Clean up event listeners
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler);
    }
  }
};

export {PDFViewer}
