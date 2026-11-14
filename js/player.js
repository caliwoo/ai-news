(function () {
  var buttons = document.querySelectorAll(".listen-btn");
  buttons.forEach(function (btn) {
    var audio = document.getElementById(btn.getAttribute("data-audio"));
    if (!audio) return;

    function sync() {
      var playing = !audio.paused && !audio.ended;
      btn.classList.toggle("is-playing", playing);
      btn.setAttribute("aria-pressed", playing ? "true" : "false");
      var label = btn.querySelector(".listen-label");
      if (label) label.textContent = playing ? "Pause this edition" : "Play this edition";
    }

    btn.addEventListener("click", function () {
      if (audio.paused) {
        document.querySelectorAll("audio").forEach(function (other) {
          if (other !== audio) other.pause();
        });
        audio.play();
      } else {
        audio.pause();
      }
    });

    audio.addEventListener("play", sync);
    audio.addEventListener("pause", sync);
    audio.addEventListener("ended", sync);
    sync();
  });
})();
