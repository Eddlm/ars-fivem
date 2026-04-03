(function () {
    const resourceName = typeof GetParentResourceName === "function"
        ? GetParentResourceName()
        : "racingsystem";

    const overlay = document.getElementById("overlay");
    const input = document.getElementById("raceUrlInput");

    function post(path, payload) {
        fetch(`https://${resourceName}/${path}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(payload || {}),
        }).catch(() => {});
    }

    function setOpen(isOpen) {
        if (isOpen) {
            overlay.style.display = "grid";
            overlay.classList.remove("hidden");
            overlay.setAttribute("aria-hidden", "false");
            input.value = "";
            setTimeout(() => input.focus(), 0);
            return;
        }

        overlay.style.display = "none";
        overlay.classList.add("hidden");
        overlay.setAttribute("aria-hidden", "true");
        input.value = "";
    }

    window.addEventListener("message", (event) => {
        const data = event.data || {};
        if (data.action !== "racingsystem:toggleGTAORacePrompt") {
            return;
        }
        setOpen(data.open === true);
    });

    window.addEventListener("keydown", (event) => {
        if (overlay.classList.contains("hidden")) {
            return;
        }

        if (event.key === "Escape") {
            event.preventDefault();
            post("racingsystem:gtAoRaceUrlCancel", {});
            return;
        }

        if (event.key === "Enter") {
            event.preventDefault();
            post("racingsystem:gtAoRaceUrlSubmit", {
                value: String(input.value || "").trim(),
            });
        }
    });
})();
