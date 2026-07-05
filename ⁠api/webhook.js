export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(200).send('OK');

  const { TELEGRAM_TOKEN, GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, ADMIN_ID } = process.env;
  const update = req.body;

  const message = update.message;
  const callbackQuery = update.callback_query;
  const msgData = message || (callbackQuery ? callbackQuery.message : null);
  
  if (!msgData) return res.status(200).send('OK');

  const chat = msgData.chat;
  const from = (message ? message.from : callbackQuery.from);
  const userId = from.id.toString();
  const adminId = ADMIN_ID.toString();
  const text = message ? message.text : null;

  const tgFetch = (method, body) => 
    fetch(`https://api.telegram.org/bot${TELEGRAM_TOKEN}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    }).then(r => r.json());

  // --- محرك قاعدة البيانات ---
  const getDB = async () => {
    const res = await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/database.json`, {
      headers: { 'Authorization': `Bearer ${GITHUB_TOKEN}`, 'Accept': 'application/vnd.github.v3+json' }
    });
    if (res.ok) {
      const data = await res.json();
      const parsed = JSON.parse(Buffer.from(data.content, 'base64').toString('utf-8'));
      return { db: parsed, sha: data.sha };
    }
    return { db: { users: {}, codes: {} }, sha: null };
  };

  const saveDB = async (dbData, sha) => {
    const content = Buffer.from(JSON.stringify(dbData, null, 2)).toString('base64');
    const body = { message: '🤖 تحديث قاعدة بيانات OBSIDIAN', content };
    if (sha) body.sha = sha;
    await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/database.json`, {
      method: 'PUT',
      headers: { 'Authorization': `Bearer ${GITHUB_TOKEN}`, 'Accept': 'application/vnd.github.v3+json' },
      body: JSON.stringify(body)
    });
  };

  const adminKeyboard = {
    inline_keyboard: [
      [{ text: '🔑 توليد كود دعوة جديد', callback_data: 'gen_code' }],
      [{ text: '👥 قائمة الموزعين', callback_data: 'list_users' }, { text: '🗑 حذف موزع', callback_data: 'help_remove' }]
    ]
  };

  // --- تفاعل أزرار الآدمن ---
  if (callbackQuery && userId === adminId) {
    const action = callbackQuery.data;
    const { db, sha } = await getDB();

    if (action === 'gen_code') {
      const newCode = 'OBS-' + Math.random().toString(36).substring(2, 8).toUpperCase();
      db.codes[newCode] = true;
      await saveDB(db, sha);
      await tgFetch('sendMessage', {
        chat_id: chat.id,
        text: `✅ **تم توليد كود جديد للاستخدام مرة واحدة:**\n\n\`${newCode}\`\n\nارسل هذا الكود للمستخدم.`,
        parse_mode: 'Markdown'
      });
    } else if (action === 'list_users') {
      let msg = Object.keys(db.users).length === 0 ? '📭 قائمة الموزعين فارغة.' : '👥 **الموزعين:**\n\n';
      for (const [id, name] of Object.entries(db.users)) msg += `👤 ${name}\n└ ID: \`${id}\`\n\n`;
      await tgFetch('sendMessage', { chat_id: chat.id, text: msg, parse_mode: 'Markdown' });
    } else if (action === 'help_remove') {
      await tgFetch('sendMessage', { chat_id: chat.id, text: '🗑 **للحذف:** ارسل\n`/remove ID`', parse_mode: 'Markdown' });
    }
    await tgFetch('answerCallbackQuery', { callback_query_id: callbackQuery.id });
    return res.status(200).send('OK');
  }

  // --- التحقق والأكواد ---
  let isAuth = (userId === adminId);
  if (!isAuth) {
    const { db } = await getDB();
    if (db.users[userId]) isAuth = true;
  }

  if (!isAuth) {
    if (text && text.startsWith('OBS-')) {
      const { db, sha } = await getDB();
      if (db.codes[text]) {
        delete db.codes[text];
        const userName = from.first_name || 'موزع';
        db.users[userId] = userName;
        await saveDB(db, sha);
        
        await tgFetch('sendMessage', { chat_id: chat.id, text: `✅ **تم تفعيل حسابك!** مرحباً ${userName}.`, parse_mode: 'Markdown' });
        await tgFetch('sendMessage', { chat_id: adminId, text: `🔔 **إشعار:** تم تفعيل \`${text}\`\nمن: ${userName}\nID: \`${userId}\``, parse_mode: 'Markdown' });
      } else {
        await tgFetch('sendMessage', { chat_id: chat.id, text: '❌ الكود غير صحيح أو مستخدم.' });
      }
    } else {
      await tgFetch('sendMessage', { chat_id: chat.id, text: '⛔️ أرسل كود الدعوة للتفعيل.' });
    }
    return res.status(200).send('OK');
  }

  // --- أوامر الآدمن ---
  if (userId === adminId && text) {
    if (text === '/start') {
      await tgFetch('sendMessage', { chat_id: chat.id, text: '👨🏻‍💻 **لوحة تحكم OBSIDIAN**', reply_markup: adminKeyboard, parse_mode: 'Markdown' });
      return res.status(200).send('OK');
    }
    if (text.startsWith('/remove ')) {
      const delId = text.split(' ')[1];
      const { db, sha } = await getDB();
      if (db.users[delId]) {
        delete db.users[delId];
        await saveDB(db, sha);
        await tgFetch('sendMessage', { chat_id: chat.id, text: `🗑 تم حذف \`${delId}\`.`, parse_mode: 'Markdown' });
      }
      return res.status(200).send('OK');
    }
  }

  // --- محرك التجميع ---
  const document = message ? message.document : null;
  const reply_to_message = message ? message.reply_to_message : null;

  if ((text && !text.startsWith('/') && !text.startsWith('OBS-')) || document) {
    if (!reply_to_message) {
      await tgFetch('sendMessage', {
        chat_id: chat.id,
        text: 'تم استلام الكود! 🚀\nيرجى **الرد على هذه الرسالة** باسم الدايلب.',
        reply_parameters: { message_id: message.message_id },
        parse_mode: 'Markdown'
      });
      return res.status(200).send('OK');
    }
  }

  if (reply_to_message && text && !text.startsWith('/')) {
    const dylibName = text.replace(/[^a-zA-Z0-9_-]/g, '');
    let codeContent = reply_to_message.text || '';

    if (reply_to_message.document) {
      const fileRes = await tgFetch('getFile', { file_id: reply_to_message.document.file_id });
      codeContent = await fetch(`https://api.telegram.org/file/bot${TELEGRAM_TOKEN}/${fileRes.result.file_path}`).then(r => r.text());
    }

    if (codeContent) {
      const waitMsg = await tgFetch('sendMessage', {
        chat_id: chat.id,
        text: `⏳ جاري تجميع \`${dylibName}\`...`,
        reply_parameters: { message_id: message.message_id },
        parse_mode: 'Markdown'
      });

      const codeBase64 = Buffer.from(codeContent, 'utf-8').toString('base64');

      await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${GITHUB_TOKEN}`, 'Content-Type': 'application/json', 'Accept': 'application/vnd.github.v3+json' },
        body: JSON.stringify({
          event_type: 'generate-dylib',
          client_payload: { chat_id: chat.id, dylib_name: dylibName, code_base64: codeBase64, wait_msg_id: waitMsg.result.message_id }
        })
      });

      const idsToDelete = [message.message_id, reply_to_message.message_id, reply_to_message.message_id - 1].filter(Boolean);
      for (const id of idsToDelete) tgFetch('deleteMessage', { chat_id: chat.id, message_id: id }).catch(() => {});
    }
  }

  return res.status(200).send('OK');
}
