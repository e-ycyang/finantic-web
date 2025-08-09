const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB();

exports.handler = async (event) => {
    // Set CORS headers
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS'
    };

    // Handle preflight OPTIONS request
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    try {
        // Parse the request body
        const { name, email } = JSON.parse(event.body);

        // Validate input
        if (!email || !email.includes('@')) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ 
                    error: 'Valid email is required' 
                })
            };
        }

        // Create timestamp
        const timestamp = new Date().toISOString();
        const id = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

        // Store in DynamoDB
        const params = {
            TableName: 'finantic-waitlist',
            Item: {
                'id': { S: id },
                'email': { S: email },
                'name': { S: name || '' },
                'timestamp': { S: timestamp },
                'source': { S: 'website' }
            }
        };

        await dynamodb.putItem(params).promise();

        console.log(`Successfully added to waitlist: ${email}`);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({ 
                success: true,
                message: 'Successfully added to waitlist'
            })
        };

    } catch (error) {
        console.error('Error processing waitlist submission:', error);
        
        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: 'Failed to process submission'
            })
        };
    }
};