const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const csv = require('csv-writer').createObjectCsvWriter;

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'build')));

// Encryption key and IV (in production, these should be environment variables)
const ENCRYPTION_KEY = crypto.randomBytes(32); // 32 bytes for AES-256
const IV_LENGTH = 16; // For AES, this is always 16 bytes

// Function to encrypt data
function encrypt(text) {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY), iv);
  let encrypted = cipher.update(text);
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return iv.toString('hex') + ':' + encrypted.toString('hex');
}

// Create CSV file if it doesn't exist
const csvFilePath = path.join(__dirname, 'data', 'waitlist.csv');

// Ensure data directory exists
if (!fs.existsSync(path.join(__dirname, 'data'))) {
  fs.mkdirSync(path.join(__dirname, 'data'));
}

// Initialize CSV writer
const csvWriter = csv({
  path: csvFilePath,
  header: [
    { id: 'timestamp', title: 'TIMESTAMP' },
    { id: 'name', title: 'NAME' },
    { id: 'email', title: 'EMAIL' }
  ],
  append: true
});

// If file doesn't exist, write headers
if (!fs.existsSync(csvFilePath)) {
  csvWriter.writeRecords([]);
}

// API endpoint to handle form submission
app.post('/api/waitlist', (req, res) => {
  try {
    const { name, email } = req.body;
    
    // Basic validation
    if (!name || !email) {
      return res.status(400).json({ success: false, message: 'Name and email are required' });
    }
    
    // Encrypt sensitive data
    const encryptedName = encrypt(name);
    const encryptedEmail = encrypt(email);
    
    // Create record
    const record = {
      timestamp: new Date().toISOString(),
      name: encryptedName,
      email: encryptedEmail
    };
    
    // Write to CSV
    csvWriter.writeRecords([record])
      .then(() => {
        res.status(200).json({ success: true, message: 'Successfully added to waitlist' });
      })
      .catch(err => {
        console.error('Error writing to CSV:', err);
        res.status(500).json({ success: false, message: 'Server error' });
      });
    
  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

// Serve React app in production
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
}); 