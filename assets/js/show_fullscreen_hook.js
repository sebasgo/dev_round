const ShowFullScreen = {
    mounted() {
        this.targetId = this.el.dataset.target;
        this.el.addEventListener('click', () => {
            this.showFullScreen();
        });
    },

    showFullScreen() {
        const target = document.getElementById(this.targetId);
        target.requestFullscreen();
    }
}

export {ShowFullScreen}
