/*
    ╔═══════════════════════════════════════════════════════════════════╗
    ║              STARCHASE GPS PURSUIT SYSTEM - JAVASCRIPT            ║
    ╚═══════════════════════════════════════════════════════════════════╝
*/

// Icon mappings for different notification types
const ICONS = {
    success: '🎯',
    error: '⛔',
    warning: '⚠️',
    info: '📡'
};

// Badge text mappings
const BADGES = {
    success: 'GPS SYSTEM',
    error: 'SYSTEM ALERT',
    warning: 'CAUTION',
    info: 'GPS TRACKING'
};

// Listen for NUI messages from the client
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'showNotification') {
        createNotification(data.type, data.title, data.message, data.duration);
    }
});

// Create and display a notification
function createNotification(type, title, message, duration = 5000) {
    const container = document.getElementById('notification-container');
    
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    
    // Get icon and badge for this type
    const icon = ICONS[type] || ICONS.info;
    const badge = BADGES[type] || BADGES.info;
    
    // Build notification HTML
    notification.innerHTML = `
        <div class="notification-glow"></div>
        <div class="notification-scanline"></div>
        <div class="notification-header">
            <div class="notification-icon">
                ${icon}
            </div>
            <div class="notification-title-group">
                <span class="notification-badge">${badge}</span>
                <div class="notification-title">${escapeHtml(title)}</div>
            </div>
        </div>
        <div class="notification-body">
            <div class="notification-message">${formatMessage(message)}</div>
        </div>
        <div class="notification-progress">
            <div class="notification-progress-bar" style="animation-duration: ${duration}ms;"></div>
        </div>
    `;
    
    // Add to container
    container.appendChild(notification);
    
    // Play sound effect (handled by client-side Lua)
    
    // Auto remove after duration
    setTimeout(() => {
        notification.classList.add('hide');
        
        // Remove from DOM after animation
        setTimeout(() => {
            if (notification.parentNode) {
                notification.parentNode.removeChild(notification);
            }
        }, 400);
    }, duration);
    
    // Limit max notifications on screen
    limitNotifications(container, 5);
}

// Format message with special styling
function formatMessage(message) {
    if (!message) return '';
    
    // Escape HTML first
    let formatted = escapeHtml(message);
    
    // Highlight plate numbers (typical format: 8 characters)
    formatted = formatted.replace(/\b([A-Z0-9]{5,8})\b/g, '<span class="plate-highlight">$1</span>');
    
    // Replace newlines with <br>
    formatted = formatted.replace(/\n/g, '<br>');
    
    return formatted;
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    if (!text) return '';
    
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Limit the number of notifications on screen
function limitNotifications(container, max) {
    const notifications = container.getElementsByClassName('notification');
    
    while (notifications.length > max) {
        const oldest = notifications[0];
        oldest.classList.add('hide');
        
        setTimeout(() => {
            if (oldest.parentNode) {
                oldest.parentNode.removeChild(oldest);
            }
        }, 400);
    }
}

// NUI callback function
function nuiCallback(name, data) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    });
}

// Get parent resource name
function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'starchase';
}

// Debug: Test notifications (remove in production)
// Uncomment to test in browser
/*
document.addEventListener('DOMContentLoaded', function() {
    setTimeout(() => {
        createNotification('success', '🎯 TARGET ACQUIRED', 'Now tracking vehicle\nPlate: ABC12345', 5000);
    }, 500);
    
    setTimeout(() => {
        createNotification('info', '📡 NEW GPS TRACK', 'Vehicle XYZ789 is now being tracked\nTime remaining: 15 minutes', 5000);
    }, 1500);
    
    setTimeout(() => {
        createNotification('warning', '⏱️ COOLDOWN', 'Cooldown: 5 seconds', 3000);
    }, 2500);
    
    setTimeout(() => {
        createNotification('error', '⛔ ACCESS DENIED', 'You must be Law Enforcement to use this', 4000);
    }, 3500);
});
*/

