window.startClock = function(selector) {
    var updateClock = function() {
        var now = new Date();
        var hours = String(now.getHours()).padStart(2, '0');
        var minutes = String(now.getMinutes()).padStart(2, '0');
        var seconds = String(now.getSeconds()).padStart(2, '0');
        var element = document.querySelector(selector);
        if (element) {
            element.textContent = hours + ":" + minutes + ":" + seconds;
        }
    };
    
    updateClock();
    return setInterval(updateClock, 1000);
};
