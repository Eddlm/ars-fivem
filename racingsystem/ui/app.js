const resourceName = (window.GetParentResourceName && window.GetParentResourceName()) || 'racingsystem';

const overlay = document.getElementById('overlay');
const urlInput = document.getElementById('urlInput');
const submitBtn = document.getElementById('submitBtn');
const cancelBtn = document.getElementById('cancelBtn');

function postNui(eventName, payload) {
    return fetch(`https://${resourceName}/${eventName}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(payload || {}),
    }).catch(() => {
        // NUI errors should not crash UI flow.
    });
}

function setOpen(open) {
    const isOpen = open === true;
    overlay.classList.toggle('hidden', !isOpen);
    overlay.setAttribute('aria-hidden', isOpen ? 'false' : 'true');

    if (isOpen) {
        requestAnimationFrame(() => {
            urlInput.focus();
            urlInput.select();
        });
    } else {
        urlInput.value = '';
    }
}

function submitValue() {
    const value = (urlInput.value || '').trim();
    postNui('racingsystem:gtAoRaceUrlSubmit', { value });
}

function cancelPrompt() {
    postNui('racingsystem:gtAoRaceUrlCancel', {});
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'racingsystem:toggleGTAORacePrompt') {
        setOpen(data.open === true);
    }
});

submitBtn.addEventListener('click', submitValue);
cancelBtn.addEventListener('click', cancelPrompt);

urlInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        event.preventDefault();
        submitValue();
    } else if (event.key === 'Escape') {
        event.preventDefault();
        cancelPrompt();
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !overlay.classList.contains('hidden')) {
        event.preventDefault();
        cancelPrompt();
    }
});

setOpen(false);
