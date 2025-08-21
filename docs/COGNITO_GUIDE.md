# AWS Cognito User Management Guide

## Understanding Email Aliases in Cognito

This Cognito User Pool is configured with **email aliases**, which means:

### For End Users (Sign-in)
- ✅ **Sign in with email address**: `demo@example.com`
- ✅ **Use email for password reset**
- ✅ **Receive notifications at email address**

### For Administrators (User Management)
- ⚠️ **Internal usernames are different from email addresses**
- ⚠️ **Use internal username for admin operations** (delete, reset, enable/disable)

## User Creation Process

When you create a user with email `john@example.com`:

1. **Cognito generates internal username**: `john_at_example_dot_com`
2. **Email is stored as an attribute**: `john@example.com`
3. **User signs in with email**: `john@example.com`
4. **Admin operations use username**: `john_at_example_dot_com`

## Common Operations

### Creating Users
```bash
# Create user - use email address
./scripts/manage-users.sh create john@example.com TempPass123!
```

### Listing Users
```bash
# See both internal usernames and email addresses
./scripts/manage-users.sh list
```

### Managing Existing Users
```bash
# Use internal username for admin operations
./scripts/manage-users.sh reset john_at_example_dot_com NewPass456!
./scripts/manage-users.sh disable john_at_example_dot_com
./scripts/manage-users.sh enable john_at_example_dot_com
./scripts/manage-users.sh delete john_at_example_dot_com
```

## Demo User Details

- **Internal Username**: `demouser`
- **Email Address**: `demo@example.com`
- **Sign-in Method**: Use email address `demo@example.com`
- **Admin Operations**: Use username `demouser`

## Troubleshooting

### "Username cannot be of email format" Error
This happens when trying to create a user with an email as the username. The fix:
- ✅ Use the `manage-users.sh` script (handles this automatically)
- ❌ Don't use email addresses directly as usernames in AWS CLI

### User Not Found During Admin Operations
- Check the internal username with `./scripts/manage-users.sh list`
- Use the internal username (not email) for admin operations

### Sign-in Issues
- Users should always sign in with their **email address**
- Never use the internal username for sign-in

## Callback URL Configuration

This Cognito User Pool is configured **without callback URL restrictions** for development flexibility:

- ✅ **Any URL can be used** for OAuth callbacks
- ✅ **No need to update URLs** when ALB DNS changes
- ✅ **Simplified deployment** without URL management complexity

> **Production Note**: In production environments, configure specific callback URLs in the Cognito User Pool Client for enhanced security.

## Best Practices

1. **Always use the provided scripts** for user management
2. **Document internal usernames** when creating users manually
3. **Train users to sign in with email addresses**
4. **Use `list` command** to find internal usernames for admin tasks
5. **Test sign-in flow** after creating new users
6. **Configure specific callback URLs in production** for security