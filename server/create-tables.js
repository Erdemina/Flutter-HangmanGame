const AWS = require('aws-sdk');

AWS.config.update({
  region: process.env.AWS_REGION || 'eu-central-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

const dynamoDB = new AWS.DynamoDB();

async function createTables() {
  try {
    // Users tablosu
    await dynamoDB.createTable({
      TableName: 'HangmanUsers',
      KeySchema: [
        { AttributeName: 'userId', KeyType: 'HASH' }
      ],
      AttributeDefinitions: [
        { AttributeName: 'userId', AttributeType: 'S' }
      ],
      ProvisionedThroughput: {
        ReadCapacityUnits: 5,
        WriteCapacityUnits: 5
      }
    }).promise();

    console.log('Users table created successfully');

    // Match History tablosu
    await dynamoDB.createTable({
      TableName: 'HangmanMatchHistory',
      KeySchema: [
        { AttributeName: 'matchId', KeyType: 'HASH' }
      ],
      AttributeDefinitions: [
        { AttributeName: 'matchId', AttributeType: 'S' },
        { AttributeName: 'userId', AttributeType: 'S' }
      ],
      GlobalSecondaryIndexes: [
        {
          IndexName: 'UserMatches',
          KeySchema: [
            { AttributeName: 'userId', KeyType: 'HASH' }
          ],
          Projection: {
            ProjectionType: 'ALL'
          },
          ProvisionedThroughput: {
            ReadCapacityUnits: 5,
            WriteCapacityUnits: 5
          }
        }
      ],
      ProvisionedThroughput: {
        ReadCapacityUnits: 5,
        WriteCapacityUnits: 5
      }
    }).promise();

    console.log('Match History table created successfully');
  } catch (error) {
    console.error('Error creating tables:', error);
  }
}

createTables(); 