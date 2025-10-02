# Firebase Remote Config Setup Guide

This guide will help you set up Firebase Remote Config to securely manage your API keys and configuration.

## 🔐 Security Benefits

- **No hardcoded API keys** in your source code
- **Centralized configuration** management
- **Real-time updates** without app store releases
- **A/B testing** capabilities
- **Environment-specific** configurations

## 📋 Setup Steps

### 1. Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `calorie-vita`
3. Navigate to **Remote Config** in the left sidebar
4. Click **"Add parameter"** for each configuration

### 2. Required Parameters

Add these parameters to Firebase Remote Config:

#### API Configuration
```
Parameter Key: openrouter_api_key
Default Value: your_actual_api_key_here
Description: OpenRouter API key for AI services
```

```
Parameter Key: openrouter_base_url
Default Value: https://openrouter.ai/api/v1/chat/completions
Description: Base URL for OpenRouter API
```

#### AI Models
```
Parameter Key: chat_model
Default Value: openai/gpt-3.5-turbo
Description: Primary chat model
```

```
Parameter Key: vision_model
Default Value: google/gemini-pro-1.5-exp
Description: Vision model for food recognition
```

```
Parameter Key: backup_vision_model
Default Value: google/gemini-pro-1.5
Description: Backup vision model
```

#### Token Limits
```
Parameter Key: max_tokens
Default Value: 100
Description: Default max tokens
```

```
Parameter Key: chat_max_tokens
Default Value: 100
Description: Chat max tokens
```

```
Parameter Key: analytics_max_tokens
Default Value: 120
Description: Analytics max tokens
```

```
Parameter Key: vision_max_tokens
Default Value: 300
Description: Vision analysis max tokens
```

#### Temperature Settings
```
Parameter Key: temperature
Default Value: 0.7
Description: Default temperature for AI responses
```

```
Parameter Key: vision_temperature
Default Value: 0.1
Description: Temperature for vision analysis
```

#### App Information
```
Parameter Key: app_name
Default Value: Calorie Vita
Description: Application name
```

```
Parameter Key: app_url
Default Value: https://calorievita.com
Description: Application website URL
```

#### Rate Limiting
```
Parameter Key: max_requests_per_minute
Default Value: 60
Description: Maximum API requests per minute
```

```
Parameter Key: request_timeout_seconds
Default Value: 30
Description: Request timeout in seconds
```

#### Feature Flags
```
Parameter Key: enable_chat
Default Value: true
Description: Enable chat functionality
```

```
Parameter Key: enable_analytics
Default Value: true
Description: Enable analytics features
```

```
Parameter Key: enable_recommendations
Default Value: true
Description: Enable recommendations
```

```
Parameter Key: enable_image_analysis
Default Value: true
Description: Enable image analysis
```

#### Debug Settings
```
Parameter Key: enable_debug_logs
Default Value: false
Description: Enable debug logging
```

```
Parameter Key: enable_api_response_logging
Default Value: false
Description: Enable API response logging
```

### 3. Publish Configuration

1. After adding all parameters, click **"Publish changes"**
2. Add a description: "Initial secure configuration setup"
3. Click **"Publish"**

### 4. Environment-Specific Configuration (Optional)

You can create different configurations for different environments:

#### Development Environment
- Set `enable_debug_logs: true`
- Set `enable_api_response_logging: true`
- Use different API keys for testing

#### Production Environment
- Set `enable_debug_logs: false`
- Set `enable_api_response_logging: false`
- Use production API keys

### 5. Security Best Practices

#### API Key Management
- **Never commit API keys** to version control
- **Rotate API keys regularly** through Firebase Console
- **Use different keys** for development and production
- **Monitor API usage** and set up alerts

#### Access Control
- **Limit Firebase Console access** to authorized personnel only
- **Use Firebase App Check** for additional security
- **Enable audit logging** to track configuration changes

### 6. Testing Your Setup

1. **Install the app** on a device/emulator
2. **Check logs** for "Secure configuration initialized successfully"
3. **Test API calls** to ensure they work with Remote Config values
4. **Verify fallback values** work when Firebase is unavailable

### 7. Monitoring and Maintenance

#### Regular Tasks
- **Monitor API usage** and costs
- **Update configurations** as needed
- **Test fallback scenarios** regularly
- **Review access logs** for unauthorized changes

#### Emergency Procedures
- **Disable features** instantly via Remote Config
- **Switch to backup API keys** if needed
- **Roll back changes** if issues occur

## 🚀 Advanced Features

### Conditional Configuration
You can set different values based on:
- App version
- User properties
- Device type
- Geographic location

### A/B Testing
Use Remote Config to:
- Test different AI models
- Optimize token limits
- Test feature flags
- Measure user engagement

### Real-time Updates
- Configuration changes take effect within 1 hour
- Force immediate updates with `AIConfig.refresh()`
- Monitor fetch status and errors

## 📱 Usage in Code

The configuration is now accessible through:

```dart
// Initialize (done automatically in main.dart)
await AIConfig.initialize();

// Use configuration
final apiKey = AIConfig.apiKey;
final model = AIConfig.chatModel;
final maxTokens = AIConfig.maxTokens;

// Refresh configuration
await AIConfig.refresh();

// Debug configuration (masks sensitive values)
final debugConfig = AIConfig.getDebugConfig();
```

## 🔍 Troubleshooting

### Common Issues

1. **Configuration not loading**
   - Check Firebase project connection
   - Verify Remote Config is enabled
   - Check network connectivity

2. **API calls failing**
   - Verify API key is set correctly
   - Check parameter names match exactly
   - Test with default values first

3. **Performance issues**
   - Configuration is cached for 1 hour
   - Use `refresh()` sparingly
   - Monitor fetch times

### Debug Information

```dart
// Check last fetch time
final lastFetch = AIConfig.lastFetchTime;
print('Last config fetch: $lastFetch');

// Get all configuration (sensitive values masked)
final config = AIConfig.getDebugConfig();
print('Current config: $config');
```

## ✅ Security Checklist

- [ ] API keys removed from source code
- [ ] Firebase Remote Config parameters set
- [ ] Configuration published to Firebase
- [ ] App tested with Remote Config values
- [ ] Fallback values working correctly
- [ ] Access controls configured
- [ ] Monitoring and alerts set up
- [ ] Emergency procedures documented

Your API keys are now securely managed through Firebase Remote Config! 🎉
