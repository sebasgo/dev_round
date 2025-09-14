import * as pdfjsLib from 'pdfjs-dist';

// Set up PDF.js worker - Phoenix will serve this from assets
pdfjsLib.GlobalWorkerOptions.workerSrc = '/assets/pdf.worker.min.js';

const PDFViewer = {
  mounted() {
    const pdfUrl = this.el.dataset.pdfUrl;
    const pdfPageNumber = parseInt(this.el.dataset.pdfPageNumber);

    this.currentPage = pdfPageNumber;
    this.pdfDoc = null;

    this.loadPDF(pdfUrl);
    this.setupControls();

    this.handleEvent("pdf_viewer_page_turn", (payload) => {
      this.currentPage = payload.pageNumber;
      this.renderPage(this.currentPage);
    })
  },
  
  loadPDF(url) {
    const loadingTask = pdfjsLib.getDocument(url);

    loadingTask.promise.then((pdf) => {
      this.pdfDoc = pdf;

      // Update total pages
      const totalPagesEl = document.getElementById('total-pages');
      if (totalPagesEl) {
        totalPagesEl.textContent = pdf.numPages;
      }

      // Render first page
      this.renderPage(this.currentPage);

    }).catch((error) => {
      console.error('Error loading PDF:', error);
      this.pushEventTo(this.el, 'pdf_error', { error: error.message });
    });
  },

  renderPage(pageNum) {
    if (!this.pdfDoc) return;

    this.pdfDoc.getPage(pageNum).then((page) => {
      let container = document.getElementById('pdf-canvas-container');
      let canvas = document.getElementById('pdf-canvas');

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

      page.render(renderContext).promise.then(() => {
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
      });
    });
  },

  goToNextPage() {
    if (this.pdfDoc && this.currentPage < this.pdfDoc.numPages) {
      this.currentPage++;
      this.renderPage(this.currentPage);
      this.pushEventTo(this.el, 'pdf_page_turn', { page_number: this.currentPage })
    }
  },

  goToPrevPage() {
    if (this.pdfDoc && this.currentPage > 1) {
      this.currentPage--;
      this.renderPage(this.currentPage);
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

  destroyed() {
    // Clean up event listeners
    if (this.keydownHandler) {
      document.removeEventListener('keydown', this.keydownHandler);
    }
  }
};

export {PDFViewer}
