# Finantic Waitlist Server

This is a simple server to securely store waitlist entries (name and email) in a CSV file.

## Features

- Securely stores user data in an encrypted CSV file
- Provides an API endpoint for the React app to submit waitlist entries
- Timestamps each entry
- Basic data validation

## Security Features

- Encrypts sensitive data using AES-256-CBC encryption
- Generates unique random IV for each encryption
- Stores encrypted data in CSV format for easy processing

## Setup Instructions

1. Install server dependencies:
   ```
   npm install --save express cors csv-writer
   ```

2. Start the server:
   ```
   node server.js
   ```
   
   The server will run on port 5000 by default.

3. For development with auto-reload:
   ```
   npm install --save-dev nodemon
   npx nodemon server.js
   ```

## Production Considerations

For a production environment, you should:

1. Store encryption keys in environment variables, not in code
2. Use HTTPS for all communications
3. Implement rate limiting to prevent abuse
4. Add authentication for API access
5. Set up proper logging and monitoring

## CSV File

The waitlist entries are stored in `data/waitlist.csv` with encrypted values for name and email.

**WARNING:** The encryption key is generated on server start. If you restart the server, you will lose the ability to decrypt previously stored data. For a production system, you should use a persistent key stored securely. 