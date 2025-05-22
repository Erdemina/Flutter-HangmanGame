const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const fetch = require('node-fetch');
const AWS = require('aws-sdk');

// AWS yapılandırması
AWS.config.update({
  region: process.env.AWS_REGION || 'eu-central-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

const dynamoDB = new AWS.DynamoDB.DocumentClient();

// DynamoDB tablo isimleri
const USERS_TABLE = 'HangmanUsers';
const MATCH_HISTORY_TABLE = 'HangmanMatchHistory';

const wss = new WebSocket.Server({ port: 8080 });

// Oyun odalarını tutacak nesne
const rooms = new Map();
let waitingRoom = null; // Otomatik eşleşme için bekleyen oda

// WebSocket bağlantılarını tutacak Map
const clients = new Map();

wss.on('connection', (ws) => {
  console.log('New client connected');
  // İlk başta userId yok, ilk mesajdan alınacak
  ws.userId = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data);

      // İlk mesajda userId varsa ws.userId olarak ata ve clients map'ini güncelle
      if (data.userId) {
        ws.userId = data.userId;
        clients.set(ws.userId, ws);
      }

      switch (data.type) {
        case 'createRoom':
          handleCreateRoom(ws, data);
          break;
        case 'joinRoom':
          handleJoinRoom(ws, data);
          break;
        case 'makeGuess':
          handleMakeGuess(ws, data);
          break;
        case 'autoMatch':
          handleAutoMatch(ws, data);
          break;
        case 'guessWord':
          handleGuessWord(ws, data);
          break;
        case 'wordInput':
          handleWordInput(ws, data);
          break;
        default:
          sendError(ws, 'Invalid message type');
      }
    } catch (error) {
      console.error('Error processing message:', error);
      sendError(ws, 'Invalid message format');
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    if (ws.userId) {
      clients.delete(ws.userId);
    }
    // Kullanıcının bağlantısı kesildiğinde odadan çıkar
    for (const [roomId, room] of rooms.entries()) {
      if (room.hostId === ws.userId || room.guestId === ws.userId) {
        broadcastToRoom(roomId, {
          type: 'gameUpdate',
          room: {
            ...room,
            isGameOver: true,
            winner: room.hostId === ws.userId ? 'Guest' : 'Host',
          },
        });
        rooms.delete(roomId);
      }
    }
  });
});

function handleCreateRoom(ws, data) {
  const roomId = uuidv4();
  const room = {
    id: roomId,
    hostId: ws.userId,
    guestId: null,
    word: data.word.toUpperCase(),
    guessedLetters: [],
    hostLives: 5,
    guestLives: 5,
    isHostTurn: true,
    isGameOver: false,
    winner: null,
    round: 1,
    hostUserId: data.userId || '',
    guestUserId: '',
    hostName: data.hostName || '',
    guestName: '',
    trophiesUpdated: false,
  };

  rooms.set(roomId, room);
  ws.roomId = roomId;

  // Oda oluşturan kullanıcıya oda ID'sini gönder
  ws.send(JSON.stringify({
    type: 'roomCreated',
    roomId: roomId,
  }));

  // Oda durumunu güncelle
  broadcastToRoom(roomId, {
    type: 'gameUpdate',
    room: room,
  });
}

function handleJoinRoom(ws, data) {
  const room = rooms.get(data.roomId);

  if (!room) {
    sendError(ws, 'Room not found');
    return;
  }

  if (room.guestId) {
    sendError(ws, 'Room is full');
    return;
  }

  room.guestId = ws.userId;
  room.guestUserId = data.userId || '';
  room.guestName = data.guestName || '';
  ws.roomId = data.roomId;

  // Oda durumunu güncelle
  broadcastToRoom(data.roomId, {
    type: 'gameUpdate',
    room: room,
  });
}

function handleMakeGuess(ws, data) {
  console.log('Handling makeGuess:', data);
  const room = rooms.get(data.roomId);

  if (!room) {
    sendError(ws, 'Room not found');
    return;
  }

  if (room.isGameOver) {
    sendError(ws, 'Game is already over');
    return;
  }

  const isHost = room.hostId === data.userId;
  const isGuest = room.guestId === data.userId;

  console.log('Turn check:');
  console.log('- User ID:', data.userId);
  console.log('- Host ID:', room.hostId);
  console.log('- Guest ID:', room.guestId);
  console.log('- Is Host Turn:', room.isHostTurn);
  console.log('- Is Host:', isHost);
  console.log('- Is Guest:', isGuest);

  if (!isHost && !isGuest) {
    sendError(ws, 'You are not in this room');
    return;
  }

  // Sıra kontrolü
  if ((isHost && !room.isHostTurn) || (isGuest && room.isHostTurn)) {
    sendError(ws, 'Not your turn');
    return;
  }

  // Kelime tahmini mi yoksa harf tahmini mi?
  if (data.isWordGuess) {
    const guessedWord = data.word.toUpperCase();
    const currentWord = room.word.toUpperCase();
    
    // Kelime doğru mu?
    if (guessedWord === currentWord) {
      // Kelime doğru tahmin edildi - rakip can kaybeder
      if (isHost) {
        room.guestLives--;
        if (room.guestLives < 0) room.guestLives = 0;
      } else {
        room.hostLives--;
        if (room.hostLives < 0) room.hostLives = 0;
      }

      // Bir sonraki kelimeye geç
      room.currentWordIndex = (room.currentWordIndex || 0) + 1;
      
      if (room.currentWordIndex >= 5) {
        // Oyun bitti
        room.isGameOver = true;
        if (room.hostLives > room.guestLives) room.winner = 'Host';
        else if (room.guestLives > room.hostLives) room.winner = 'Guest';
        else room.winner = 'Draw';
      } else {
        // Yeni kelimeye geç
        room.word = room.words[room.currentWordIndex];
        room.maskedWord = createMaskedWord(room.word);
        room.guessedLetters = [];
        // Sıra aynı oyuncuda kalır
      }
    } else {
      // Kelime yanlış tahmin edildi - sıra karşıya geçer
      room.isHostTurn = !room.isHostTurn;
    }
  } else {
    // Harf tahmini
    const letter = data.letter.toUpperCase();
    if (room.guessedLetters.includes(letter)) {
      sendError(ws, 'Letter already guessed');
      return;
    }

    room.guessedLetters.push(letter);

    // Doğru tahmin mi?
    const currentWord = room.word.toUpperCase();
    if (currentWord.includes(letter)) {
      // Maskelenmiş kelimeyi güncelle
      room.maskedWord = currentWord.split('').map(char => {
        const upperChar = char.toUpperCase();
        return room.guessedLetters.includes(upperChar) ? char : '_';
      }).join(' ');

      // Kelime tamamen açıldı mı?
      if (currentWord.split('').every(char => 
        room.guessedLetters.includes(char.toUpperCase())
      )) {
        // Kelime tamamen açıldı - rakip can kaybeder
        if (isHost) {
          room.guestLives--;
          if (room.guestLives < 0) room.guestLives = 0;
        } else {
          room.hostLives--;
          if (room.hostLives < 0) room.hostLives = 0;
        }

        // Bir sonraki kelimeye geç
        room.currentWordIndex = (room.currentWordIndex || 0) + 1;
        
        if (room.currentWordIndex >= 5) {
          // Oyun bitti
          room.isGameOver = true;
          if (room.hostLives > room.guestLives) room.winner = 'Host';
          else if (room.guestLives > room.hostLives) room.winner = 'Guest';
          else room.winner = 'Draw';
        } else {
          // Yeni kelimeye geç
          room.word = room.words[room.currentWordIndex];
          room.maskedWord = createMaskedWord(room.word);
          room.guessedLetters = [];
          // Sıra aynı oyuncuda kalır
        }
      } else {
        // Doğru harf tahmini - sıra aynı oyuncuda kalır
      }
    } else {
      // Yanlış harf tahmini - sıra karşıya geçer
      room.isHostTurn = !room.isHostTurn;
    }
  }

  // Oyun sonu kontrolü
  if (room.hostLives <= 0 || room.guestLives <= 0) {
    room.isGameOver = true;
    room.winner = room.hostLives <= 0 ? 'Guest' : 'Host';
  }

  console.log('Broadcasting game update after makeGuess:', room);
  // Oda durumunu güncelle
  broadcastToRoom(room.id, {
    type: 'gameUpdate',
    room: room,
  });

  if (room.isGameOver) handleGameOver(room);
}

async function getRandomWord(words) {
  if (!words || words.length === 0) {
    throw new Error('No words provided');
  }
  const randomIndex = Math.floor(Math.random() * words.length);
  return words[randomIndex].toUpperCase();
}

function createMaskedWord(word) {
  return word.split('').map(() => '_').join(' ');
}

function createGameRoom(ws, data) {
  return {
    id: uuidv4(),
    hostId: data.userId,
    guestId: null,
    hostUsername: data.username,
    guestUsername: null,
    hostGladiator: data.gladiator,
    guestGladiator: null,
    hostTrophies: data.trophies || 0,  // 💥 burada tutuluyor
    guestTrophies: null,               // 💥 sonra atanacak
    isHostTurn: true,
    hostLives: 5,
    guestLives: 5,
    word: data.words[0],
    maskedWord: createMaskedWord(data.words[0]),
    guessedLetters: [],
    isGameOver: false,
    winner: null,
    currentWordIndex: 0,
    words: data.words,
    categories: data.categories
  };
}


function handleAutoMatch(ws, data) {
  console.log('AutoMatch request from:', data.username);
  console.log('User ID:', data.userId);
  
  // Bekleyen oda var mı kontrol et
  const waitingRoom = Array.from(rooms.values()).find(
    room => room.guestId === null && room.hostId !== data.userId
  );

  if (waitingRoom) {
    // Bekleyen oda bulundu, katıl
    console.log('Found waiting room, joining as guest:', data.username);
    waitingRoom.guestId = data.userId;
    waitingRoom.guestUsername = data.username;
    waitingRoom.guestGladiator = data.gladiator;
    waitingRoom.guestTrophies = data.trophies || 0; // Misafir oyuncunun kupa sayısını kaydet
    ws.roomId = waitingRoom.id;

    // Oyunu başlat
    const gameStartMessage = {
      type: 'gameStart',
      room: waitingRoom
    };

    // Her iki oyuncuya da oyun başlangıç mesajını gönder
    const hostWs = Array.from(clients.values()).find(client => client.roomId === waitingRoom.id);
    if (hostWs) {
      hostWs.send(JSON.stringify(gameStartMessage));
    }
    ws.send(JSON.stringify(gameStartMessage));
  } else {
    // Yeni bekleme odası oluştur
    console.log('Creating new waiting room for:', data.username);
    const newRoom = createGameRoom(ws, data);
    newRoom.hostId = data.userId;
    newRoom.hostUsername = data.username; // Host ismini kaydet
    newRoom.hostTrophies = data.trophies || 0; // Host kupa sayısını kaydet
    rooms.set(newRoom.id, newRoom);
    ws.roomId = newRoom.id;

    const waitingMessage = {
      type: 'waitingForOpponent',
      room: newRoom
    };
    ws.send(JSON.stringify(waitingMessage));
  }
}

function handleGuessWord(ws, data) {
  console.log('Handling guessWord:', data);
  const room = rooms.get(data.roomId);
  if (!room) {
    sendError(ws, 'Room not found');
    return;
  }
  if (room.isGameOver) {
    sendError(ws, 'Game is already over');
    return;
  }
  const isHost = room.hostId === data.userId;
  const isGuest = room.guestId === data.userId;
  if (!isHost && !isGuest) {
    sendError(ws, 'You are not in this room');
    return;
  }
  if ((isHost && !room.isHostTurn) || (isGuest && room.isHostTurn)) {
    sendError(ws, 'Not your turn');
    return;
  }
  const guess = data.word.trim().toUpperCase();
  if (guess === room.word) {
    // Doğru tahmin: rakibin canı sadece 1 azalır
    const damage = 1;
    if (isHost) {
      room.guestLives -= damage;
      if (room.guestLives < 0) room.guestLives = 0;
    } else {
      room.hostLives -= damage;
      if (room.hostLives < 0) room.hostLives = 0;
    }
    room.maskedWord = room.word; // Kelimeyi aç!
    room.currentWordIndex = (room.currentWordIndex || 0) + 1;
    if (room.currentWordIndex >= 5) {
      room.isGameOver = true;
      if (room.hostLives > room.guestLives) room.winner = 'Host';
      else if (room.guestLives > room.hostLives) room.winner = 'Guest';
      else room.winner = 'Draw';
    } else {
      // Yeni kelimeye geç
      room.word = room.words[room.currentWordIndex];
      room.maskedWord = createMaskedWord(room.word);
      room.guessedLetters = [];
      room.isHostTurn = !room.isHostTurn;
    }
  } else {
    // Yanlış tahmin: tahmin edenin canı 10 azalır
    if (isHost) {
      room.hostLives -= 10;
      if (room.hostLives < 0) room.hostLives = 0;
    } else {
      room.guestLives -= 10;
      if (room.guestLives < 0) room.guestLives = 0;
    }
    // Sırayı değiştir
    room.isHostTurn = !room.isHostTurn;
  }
  // Oyun sonu kontrolü
  if (room.hostLives <= 0 || room.guestLives <= 0) {
    room.isGameOver = true;
    room.winner = room.hostLives <= 0 ? 'Guest' : 'Host';
  }
  console.log('Broadcasting game update after guessWord:', room);
  // Oda durumunu güncelle
  broadcastToRoom(data.roomId, {
    type: 'gameUpdate',
    room: room,
  });

  if (room.isGameOver) handleGameOver(room);
}

function handleWordInput(ws, data) {
  // PvP modunda kullanılmaz, ignore et
  return;
}

function broadcastToRoom(roomId, message) {
  const room = rooms.get(roomId);
  if (!room) {
    console.log('Room not found for broadcast:', roomId);
    return;
  }

  console.log('Broadcasting to room:', roomId, 'Message type:', message.type, 'Room state:', room);
  
  // Get the WebSocket connections for both players
  const hostWs = clients.get(room.hostId);
  const guestWs = clients.get(room.guestId);

  // Send to host if connected
  if (hostWs && hostWs.readyState === WebSocket.OPEN) {
    console.log('Sending to host:', room.hostId);
    hostWs.send(JSON.stringify(message));
  }

  // Send to guest if connected
  if (guestWs && guestWs.readyState === WebSocket.OPEN) {
    console.log('Sending to guest:', room.guestId);
    guestWs.send(JSON.stringify(message));
  }
}

function sendError(ws, message) {
  ws.send(JSON.stringify({
    type: 'error',
    message: message,
  }));
}

async function updateTrophy(userId, trophyChange) {
  try {
    const params = {
      TableName: USERS_TABLE,
      Key: { userId },
      UpdateExpression: 'ADD trophies :trophyChange',
      ExpressionAttributeValues: {
        ':trophyChange': trophyChange
      },
      ReturnValues: 'UPDATED_NEW'
    };

    const result = await dynamoDB.update(params).promise();
    return result.Attributes.trophies;
  } catch (error) {
    console.error('Error updating trophy:', error);
    throw error;
  }
}

async function addMatchHistory(matchResult, trophyCount, userId, opponentName) {
  try {
    const params = {
      TableName: MATCH_HISTORY_TABLE,
      Item: {
        matchId: uuidv4(),
        userId,
        opponentName,
        result: matchResult,
        trophyChange: trophyCount,
        timestamp: new Date().toISOString()
      }
    };

    await dynamoDB.put(params).promise();
  } catch (error) {
    console.error('Error adding match history:', error);
    throw error;
  }
}

async function getTrophyCount(userId) {
  try {
    const params = {
      TableName: USERS_TABLE,
      Key: { userId }
    };
    const result = await dynamoDB.get(params).promise();
    if (result.Item && typeof result.Item.trophies === 'number') {
      return result.Item.trophies;
    }
    return 0;
  } catch (error) {
    console.error('Error getting trophy count:', error);
    return 0;
  }
}

function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function handleGameOver(room) {
  if (room.trophiesUpdated) return;
  room.trophiesUpdated = true;

  let winnerId, loserId, winnerName, loserName;
  if (room.winner === 'Host') {
    winnerId = room.hostId;
    loserId = room.guestId;
    winnerName = room.hostUsername;
    loserName = room.guestUsername;
  } else if (room.winner === 'Guest') {
    winnerId = room.guestId;
    loserId = room.hostId;
    winnerName = room.guestUsername;
    loserName = room.hostUsername;
  } else {
    return;
  }

  try {
    // Kupa değişimlerini belirle
    const winnerTrophyChange = 10;
    const loserTrophyChange = -5;

    // Önce değişimi uygula
    await fetch('https://uxjrhphe8e.execute-api.eu-north-1.amazonaws.com/addTrophy', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: winnerId, trophies: winnerTrophyChange })
    });
    await fetch('https://uxjrhphe8e.execute-api.eu-north-1.amazonaws.com/addTrophy', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ userId: loserId, trophies: loserTrophyChange })
    });

    // Maç geçmişi kaydı (sadece değişim yaz)
    await fetch('https://6mfqpxj1i0.execute-api.eu-north-1.amazonaws.com/addhistory', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        historyId: uuidv4(),
        userId: winnerId,
        opponentName: loserName,
        matchResult: 'WIN',
        trophyCount: winnerTrophyChange,
        playedAt: new Date().toISOString()
      })
    });
    await fetch('https://6mfqpxj1i0.execute-api.eu-north-1.amazonaws.com/addhistory', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        historyId: uuidv4(),
        userId: loserId,
        opponentName: winnerName,
        matchResult: 'LOSE',
        trophyCount: loserTrophyChange,
        playedAt: new Date().toISOString()
      })
    });

    // Broadcast success to both players (hala toplam kupa ile)
    // İstersen burada da trophyChange gönderebilirsin
    broadcastToRoom(room.id, {
      type: 'trophyUpdate',
      winner: {
        userId: winnerId,
        trophies: winnerTrophyChange,
        matchResult: 'WIN',
        opponentName: loserName
      },
      loser: {
        userId: loserId,
        trophies: loserTrophyChange,
        matchResult: 'LOSE',
        opponentName: winnerName
      }
    });

  } catch (error) {
    console.error('Error updating match history and trophies:', error);
    broadcastToRoom(room.id, {
      type: 'error',
      message: 'Failed to update trophies and match history: ' + error.message
    });
  }
}


console.log('WebSocket server is running on port 8080'); 