# Migrating from Pusher to Centrifugo - Vue.js Guide

This guide will help you migrate your Vue.js application from Pusher to Centrifugo.

## Installation

### 1. Install Centrifugo Client Library

```bash
npm install centrifuge
```

## Setup

### 2. Create a Centrifugo Service

Create a new file `src/services/centrifugo.js`:

```javascript
import { Centrifuge } from 'centrifuge';

const CENTRIFUGO_URL = import.meta.env.VITE_CENTRIFUGO_URL;
const SECRET = import.meta.env.VITE_CENTRIFUGO_SECRET;

class CentrifugoService {
  constructor() {
    this.centrifuge = null;
    this.token = null;
  }

  /**
   * Initialize Centrifugo connection
   * @param {string} userId - Unique user identifier
   * @param {object} userData - Additional user data (optional)
   */
  async init(userId, userData = {}) {
    // Generate JWT token on your backend
    // For now, you can use this client-side (NOT recommended for production)
    const token = await this.generateToken(userId, userData);
    
    this.centrifuge = new Centrifuge(CENTRIFUGO_URL, {
      token: token,
      debug: true // Set to false in production
    });

    this.centrifuge.on('connected', () => {
      console.log('✓ Connected to Centrifugo');
    });

    this.centrifuge.on('disconnected', (ctx) => {
      console.log('✗ Disconnected from Centrifugo:', ctx.reason);
    });

    this.centrifuge.on('error', (ctx) => {
      console.error('✗ Centrifugo error:', ctx.error);
    });

    this.centrifuge.connect();
  }

  /**
   * Generate JWT token (IMPORTANT: Move this to your backend in production!)
   * @param {string} userId - User ID
   * @param {object} userData - Additional user data
   */
  async generateToken(userId, userData = {}) {
    // In production, call your backend API to generate the token
    // Example:
    // const response = await fetch('/api/centrifugo-token', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify({ userId, ...userData })
    // });
    // return response.json().token;

    // For development only - DO NOT use in production
    const jwt = require('jsonwebtoken');
    return jwt.sign(
      {
        sub: userId,
        iat: Math.floor(Date.now() / 1000),
        subs: {
          [userData.channel || 'default']: {}
        }
      },
      SECRET,
      { algorithm: 'HS256' }
    );
  }

  /**
   * Subscribe to a channel
   * @param {string} channel - Channel name
   * @param {function} onMessage - Callback for new messages
   */
  subscribe(channel, onMessage) {
    const sub = this.centrifuge.getSubscription(channel);
    
    if (!sub) {
      const newSub = this.centrifuge.newSubscription(channel);
      
      newSub.on('publication', (ctx) => {
        console.log('Message received:', ctx.data);
        onMessage(ctx.data);
      });

      newSub.on('subscribed', () => {
        console.log(`✓ Subscribed to channel: ${channel}`);
      });

      newSub.on('error', (ctx) => {
        console.error(`✗ Subscription error on ${channel}:`, ctx.error);
      });

      newSub.subscribe();
      return newSub;
    }
    
    return sub;
  }

  /**
   * Unsubscribe from a channel
   * @param {string} channel - Channel name
   */
  unsubscribe(channel) {
    const sub = this.centrifuge.getSubscription(channel);
    if (sub) {
      sub.unsubscribe();
    }
  }

  /**
   * Disconnect from Centrifugo
   */
  disconnect() {
    if (this.centrifuge) {
      this.centrifuge.disconnect();
    }
  }
}

export default new CentrifugoService();
```

## Usage in Vue Components

### 3. Replace Pusher with Centrifugo

**Before (Pusher):**
```vue
<script>
import Pusher from 'pusher-js';

export default {
  data() {
    return {
      messages: []
    };
  },
  mounted() {
    const pusher = new Pusher('YOUR_PUSHER_KEY', {
      cluster: 'mt1'
    });
    
    const channel = pusher.subscribe('my-channel');
    channel.bind('message', (data) => {
      this.messages.push(data);
    });
  }
};
</script>
```

**After (Centrifugo):**
```vue
<script>
import centrifugoService from '@/services/centrifugo';

export default {
  data() {
    return {
      messages: []
    };
  },
  async mounted() {
    // Initialize Centrifugo with user ID
    await centrifugoService.init('user123', {
      channel: 'my-channel'
    });
    
    // Subscribe to channel
    centrifugoService.subscribe('my-channel', (message) => {
      this.messages.push(message);
    });
  },
  beforeUnmount() {
    centrifugoService.unsubscribe('my-channel');
  }
};
</script>
```

## Backend Integration (Node.js/Express Example)

### 4. Generate Tokens on Your Backend

Create an endpoint to generate JWT tokens:

```javascript
// backend/routes/centrifugo.js
const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();

const SECRET = 'Biyo_1_Secret_2025!'; // Use environment variable in production

router.post('/centrifugo-token', (req, res) => {
  const { userId, channel } = req.body;
  
  // Verify user is authenticated
  if (!req.user) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const token = jwt.sign(
    {
      sub: userId,
      iat: Math.floor(Date.now() / 1000),
      subs: {
        [channel]: {}
      }
    },
    SECRET,
    { algorithm: 'HS256' }
  );

  res.json({ token });
});

module.exports = router;
```

## Publishing Messages

### 5. Publish from Your Backend

**Using HTTP API:**
```bash
curl -X POST https://biyo-websocket-server-jzdsc.ondigitalocean.app/api/publish \
  -H "Content-Type: application/json" \
  -H "Authorization: apikey YOUR_API_KEY" \
  -d '{
    "channel": "my-channel",
    "data": {
      "text": "Hello from backend!",
      "timestamp": '$(date +%s)'
    }
  }'
```

**Using Node.js:**
```javascript
const axios = require('axios');

async function publishMessage(channel, data) {
  try {
    await axios.post(
      'https://biyo-websocket-server-jzdsc.ondigitalocean.app/api/publish',
      {
        channel: channel,
        data: data
      },
      {
        headers: {
          'Authorization': `apikey ${process.env.CENTRIFUGO_API_KEY}`
        }
      }
    );
    console.log('Message published');
  } catch (error) {
    console.error('Failed to publish:', error);
  }
}

// Usage
publishMessage('my-channel', {
  text: 'Hello from backend!',
  timestamp: Date.now()
});
```

## Common Patterns

### Real-time Chat

```vue
<template>
  <div class="chat">
    <div class="messages">
      <div v-for="msg in messages" :key="msg.id" class="message">
        <strong>{{ msg.user }}:</strong> {{ msg.text }}
      </div>
    </div>
    <input 
      v-model="newMessage" 
      @keyup.enter="sendMessage"
      placeholder="Type a message..."
    />
  </div>
</template>

<script>
import centrifugoService from '@/services/centrifugo';

export default {
  data() {
    return {
      messages: [],
      newMessage: '',
      channel: 'chat-room-1'
    };
  },
  async mounted() {
    await centrifugoService.init(this.$route.params.userId);
    centrifugoService.subscribe(this.channel, (message) => {
      this.messages.push(message);
    });
  },
  methods: {
    async sendMessage() {
      if (!this.newMessage.trim()) return;
      
      // Send to backend API
      await fetch('/api/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          channel: this.channel,
          text: this.newMessage,
          user: this.$route.params.userId
        })
      });
      
      this.newMessage = '';
    }
  },
  beforeUnmount() {
    centrifugoService.unsubscribe(this.channel);
  }
};
</script>
```

### Live Notifications

```vue
<script>
import centrifugoService from '@/services/centrifugo';

export default {
  data() {
    return {
      notifications: []
    };
  },
  async mounted() {
    await centrifugoService.init(this.userId);
    
    // Subscribe to personal notification channel
    centrifugoService.subscribe(`user:${this.userId}:notifications`, (notification) => {
      this.notifications.push(notification);
      
      // Show toast/alert
      this.$toast.show(notification.message);
    });
  }
};
</script>
```

## Key Differences from Pusher

| Feature | Pusher | Centrifugo |
|---------|--------|-----------|
| **Authentication** | API Key | JWT Token |
| **Channels** | Public/Private/Presence | Channels with permissions |
| **Message Limit** | Limited by plan | Unlimited |
| **Self-hosted** | No | Yes ✓ |
| **Cost** | Subscription | Free (self-hosted) |
| **Token Generation** | Client-side | Backend (recommended) |

## Security Best Practices

1. **Generate tokens on backend** - Never expose your secret key to the client
2. **Use environment variables** - Store `CENTRIFUGO_CLIENT_TOKEN_HMAC_SECRET_KEY` securely
3. **Set token expiration** - Add `exp` claim to JWT tokens
4. **Validate user permissions** - Check channel access on backend before generating token
5. **Use HTTPS/WSS** - Always use secure connections in production

## Environment Variables

### Development (.env.local)

Create a `.env.local` file in your Vue.js project root:

```env
VITE_CENTRIFUGO_URL=wss://biyo-websocket-server-jzdsc.ondigitalocean.app/connection/websocket
VITE_CENTRIFUGO_SECRET=Biyo_1_Secret_2025!
VITE_API_URL=https://your-backend-api.com
```

### Production (.env.production)

Create a `.env.production` file:

```env
VITE_CENTRIFUGO_URL=wss://biyo-websocket-server-jzdsc.ondigitalocean.app/connection/websocket
VITE_CENTRIFUGO_SECRET=your_production_secret
VITE_API_URL=https://your-production-api.com
```

### Add to .gitignore

Make sure your `.gitignore` includes:

```
.env.local
.env.*.local
```

This prevents accidental commits of secrets.

### Using in Your Service

The service automatically uses these variables:

```javascript
const CENTRIFUGO_URL = import.meta.env.VITE_CENTRIFUGO_URL;
const SECRET = import.meta.env.VITE_CENTRIFUGO_SECRET;
```

### Vite Configuration (vite.config.js)

If you need to access environment variables in your Vite config:

```javascript
import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig(({ command, mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  
  return {
    plugins: [vue()],
    define: {
      __CENTRIFUGO_URL__: JSON.stringify(env.VITE_CENTRIFUGO_URL),
      __CENTRIFUGO_SECRET__: JSON.stringify(env.VITE_CENTRIFUGO_SECRET),
    }
  };
});
```

## Troubleshooting

### Connection Issues
- Check WebSocket URL is correct
- Verify JWT token is valid
- Check browser console for errors

### Permission Denied
- Ensure JWT token includes channel in `subs` field
- Verify user has permission to subscribe

### Messages Not Received
- Check channel name matches exactly
- Verify backend is publishing to correct channel
- Check Centrifugo logs for errors

## Support

- [Centrifugo Documentation](https://centrifugal.dev)
- [Centrifuge JS Client](https://github.com/centrifugal/centrifuge-js)
- [Server API Reference](https://centrifugal.dev/docs/server/server_api)

## Next Steps

1. Update your backend to generate JWT tokens
2. Replace Pusher client with Centrifugo client
3. Test real-time messaging in development
4. Deploy to production
5. Monitor logs and performance
