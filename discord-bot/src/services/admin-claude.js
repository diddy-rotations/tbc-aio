import Anthropic from '@anthropic-ai/sdk';
import { ChannelType, PermissionsBitField, ActionRowBuilder, ButtonBuilder, ButtonStyle, ModalBuilder, TextInputBuilder, TextInputStyle, EmbedBuilder } from 'discord.js';
import { config } from '../config.js';

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT = `You are the Diddy AIO Discord server administrator assistant.
You help manage the Discord server for the Diddy AIO WoW TBC rotation addon community.

## ABOUT THIS COMMUNITY
- Diddy AIO is a multi-class WoW TBC rotation addon supporting Druid and Hunter
- The community includes WoW players who use the addon, testers, and developers
- Useful channel categories might include: Announcements, Support, Class Discussion, Development, General
- Useful channels might include: announcements, releases, rules, faq, general-chat, support, bug-reports, feature-requests, druid-discussion, hunter-discussion, dev-updates, testing
- You have good judgement about Discord server structure — use it

## YOUR CAPABILITIES
You can read the current server structure, ask the admin questions, propose plans, and execute approved changes.

## TOOL TIERS

### Read-Only (use freely)
- list_channels: See all current channels with IDs, types, categories
- list_roles: See all roles with IDs, names, member counts
- get_server_info: Server metadata (name, member count, etc.)
- read_channel_messages: Read recent messages in a channel

### Interactive (pauses for admin input)
- ask_question: Ask clarifying questions. Provide predefined options when possible for quick button responses. Ask all related questions at once in a single call rather than one at a time.
- propose_plan: Present your plan for approval. REQUIRED before any execution tools.

### Execution (requires prior approval via propose_plan)
- create_category: Create a channel category
- create_channel: Create a text or voice channel
- send_message: Send a message or embed to a channel
- set_channel_permissions: Set permission overwrites on a channel

## WORKFLOW (STRICT — follow this order)
1. Read the current server state with read-only tools
2. If the request is unclear, use ask_question to clarify
3. Formulate a concrete plan based on what you learned
4. Call propose_plan with a summary and step list — this is MANDATORY before any changes
5. If approved: execute each step using execution tools
6. If denied: revise based on feedback, then propose again
7. Summarize what was accomplished

## RULES
- NEVER skip the propose_plan step. Always get explicit approval before executing.
- Keep channel names lowercase with hyphens (Discord convention).
- When creating channels, consider: category placement, permissions, topic description.
- Prefer one ask_question call with multiple sub-questions over multiple separate calls.
- If the admin's request is completely clear, skip ask_question and go straight to propose_plan.
- Be concise in plan steps. Each step = one concrete action.
- After execution, summarize what was done with channel names and IDs.
- If a tool call fails, inform the admin and suggest a fix (e.g. missing bot permissions).
- For permission overwrites, use Discord permission flag names exactly: ViewChannel, SendMessages, ManageMessages, EmbedLinks, AttachFiles, AddReactions, etc.`;

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

const TOOLS = [
  // --- Read-only ---
  {
    name: 'list_channels',
    description: 'List all channels and categories in the server with IDs, types, categories, and positions.',
    input_schema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'list_roles',
    description: 'List all roles in the server with IDs, names, colors, and member counts.',
    input_schema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'get_server_info',
    description: 'Get server metadata: name, member count, boost level, channel count, role count.',
    input_schema: { type: 'object', properties: {}, required: [] },
  },
  {
    name: 'read_channel_messages',
    description: 'Read the most recent messages in a channel.',
    input_schema: {
      type: 'object',
      properties: {
        channel_id: { type: 'string', description: 'The channel ID to read from' },
        limit: { type: 'number', description: 'Number of messages to fetch (1-25, default 10)' },
      },
      required: ['channel_id'],
    },
  },
  // --- Interactive ---
  {
    name: 'ask_question',
    description: 'Ask the admin a clarifying question. The loop pauses until they respond. Provide predefined options for quick button responses when possible.',
    input_schema: {
      type: 'object',
      properties: {
        question: { type: 'string', description: 'The question to ask' },
        options: {
          type: 'array',
          items: { type: 'string' },
          description: 'Predefined answer choices shown as buttons (max 4). Omit for free-text input.',
        },
      },
      required: ['question'],
    },
  },
  {
    name: 'propose_plan',
    description: 'Present a numbered action plan for admin approval. REQUIRED before any execution tools. The loop pauses until they approve or deny.',
    input_schema: {
      type: 'object',
      properties: {
        summary: { type: 'string', description: 'Brief summary of what will happen' },
        steps: {
          type: 'array',
          items: { type: 'string' },
          description: 'Ordered list of concrete actions to take',
        },
      },
      required: ['summary', 'steps'],
    },
  },
  // --- Execution ---
  {
    name: 'create_category',
    description: 'Create a new channel category.',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Category name' },
        position: { type: 'number', description: 'Optional position in the channel list' },
      },
      required: ['name'],
    },
  },
  {
    name: 'create_channel',
    description: 'Create a text or voice channel, optionally under a category.',
    input_schema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Channel name (lowercase, hyphens)' },
        type: { type: 'string', enum: ['text', 'voice'], description: 'Channel type' },
        parent_id: { type: 'string', description: 'Category ID to nest under (optional)' },
        topic: { type: 'string', description: 'Channel topic (text channels only, optional)' },
      },
      required: ['name', 'type'],
    },
  },
  {
    name: 'send_message',
    description: 'Send a message or rich embed to a channel.',
    input_schema: {
      type: 'object',
      properties: {
        channel_id: { type: 'string', description: 'Target channel ID' },
        content: { type: 'string', description: 'Plain text content (optional if embed is provided)' },
        embed: {
          type: 'object',
          description: 'Optional rich embed with title, description, color, fields',
          properties: {
            title: { type: 'string' },
            description: { type: 'string' },
            color: { type: 'number', description: 'Decimal color value (e.g. 5793266 for blurple)' },
            fields: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  value: { type: 'string' },
                  inline: { type: 'boolean' },
                },
                required: ['name', 'value'],
              },
            },
          },
        },
      },
      required: ['channel_id'],
    },
  },
  {
    name: 'set_channel_permissions',
    description: 'Set permission overwrites on a channel for a role or user.',
    input_schema: {
      type: 'object',
      properties: {
        channel_id: { type: 'string', description: 'Channel to modify' },
        target_id: { type: 'string', description: 'Role ID or user ID' },
        target_type: { type: 'string', enum: ['role', 'member'], description: 'Whether target is a role or member' },
        allow: {
          type: 'array',
          items: { type: 'string' },
          description: 'Permission flags to allow (e.g. ["ViewChannel", "SendMessages"])',
        },
        deny: {
          type: 'array',
          items: { type: 'string' },
          description: 'Permission flags to deny (e.g. ["SendMessages"])',
        },
      },
      required: ['channel_id', 'target_id', 'target_type'],
    },
  },
];

const INTERACTIVE_TOOLS = new Set(['ask_question', 'propose_plan']);
const EXECUTION_TOOLS = new Set(['create_category', 'create_channel', 'send_message', 'set_channel_permissions']);

// ---------------------------------------------------------------------------
// Interactive tool handlers (pause loop, show Discord UI, await response)
// ---------------------------------------------------------------------------

async function handleAskQuestion(interaction, input) {
  const { question, options } = input;

  if (options && options.length > 0) {
    // Button-based: one button per option + Cancel
    const buttons = options.slice(0, 4).map((opt, i) =>
      new ButtonBuilder()
        .setCustomId(`admin_answer_${i}`)
        .setLabel(opt.slice(0, 80))
        .setStyle(ButtonStyle.Primary)
    );
    buttons.push(
      new ButtonBuilder()
        .setCustomId('admin_cancel')
        .setLabel('Cancel')
        .setStyle(ButtonStyle.Danger)
    );

    const row = new ActionRowBuilder().addComponents(buttons);
    const embed = new EmbedBuilder()
      .setTitle('Question')
      .setDescription(question)
      .setColor(0xfee75c);

    const msg = await interaction.followUp({ embeds: [embed], components: [row] });

    try {
      const response = await msg.awaitMessageComponent({
        filter: (i) => i.user.id === interaction.user.id,
        time: 120_000,
      });

      await response.update({ components: [] });

      if (response.customId === 'admin_cancel') {
        throw new AdminCancelError();
      }

      const idx = parseInt(response.customId.split('_').pop());
      return options[idx];
    } catch (err) {
      if (err instanceof AdminCancelError) throw err;
      await msg.edit({ components: [] }).catch(() => {});
      throw new AdminTimeoutError();
    }
  } else {
    // Free-text: "Type Answer" button opens a modal, + Cancel
    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId('admin_modal_trigger')
        .setLabel('Type Answer')
        .setStyle(ButtonStyle.Primary),
      new ButtonBuilder()
        .setCustomId('admin_cancel')
        .setLabel('Cancel')
        .setStyle(ButtonStyle.Danger),
    );
    const embed = new EmbedBuilder()
      .setTitle('Question')
      .setDescription(question)
      .setColor(0xfee75c);

    const msg = await interaction.followUp({ embeds: [embed], components: [row] });

    try {
      const btnResponse = await msg.awaitMessageComponent({
        filter: (i) => i.user.id === interaction.user.id,
        time: 120_000,
      });

      if (btnResponse.customId === 'admin_cancel') {
        await btnResponse.update({ components: [] });
        throw new AdminCancelError();
      }

      // Show modal for free-text input
      const modal = new ModalBuilder()
        .setCustomId('admin_answer_modal')
        .setTitle('Your Answer')
        .addComponents(
          new ActionRowBuilder().addComponents(
            new TextInputBuilder()
              .setCustomId('answer')
              .setLabel('Answer')
              .setStyle(TextInputStyle.Paragraph)
              .setPlaceholder('Type your answer...')
              .setRequired(true)
          )
        );

      await btnResponse.showModal(modal);

      const modalSubmit = await btnResponse.awaitModalSubmit({
        filter: (i) => i.user.id === interaction.user.id,
        time: 120_000,
      });

      await modalSubmit.deferUpdate();
      await msg.edit({ components: [] }).catch(() => {});

      return modalSubmit.fields.getTextInputValue('answer');
    } catch (err) {
      if (err instanceof AdminCancelError) throw err;
      await msg.edit({ components: [] }).catch(() => {});
      throw new AdminTimeoutError();
    }
  }
}

async function handleProposePlan(interaction, input, state) {
  const { summary, steps } = input;
  const stepList = steps.map((s, i) => `**${i + 1}.** ${s}`).join('\n');

  const embed = new EmbedBuilder()
    .setTitle('Proposed Plan')
    .setDescription(`${summary}\n\n${stepList}`)
    .setColor(0xf0b232)
    .setFooter({ text: 'Review carefully before approving.' });

  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId('admin_approve').setLabel('Approve').setStyle(ButtonStyle.Success),
    new ButtonBuilder().setCustomId('admin_deny').setLabel('Deny').setStyle(ButtonStyle.Danger),
    new ButtonBuilder().setCustomId('admin_cancel').setLabel('Cancel').setStyle(ButtonStyle.Secondary),
  );

  const msg = await interaction.followUp({ embeds: [embed], components: [row] });

  try {
    const response = await msg.awaitMessageComponent({
      filter: (i) => i.user.id === interaction.user.id,
      time: 120_000,
    });

    if (response.customId === 'admin_approve') {
      const approvedEmbed = EmbedBuilder.from(embed).setColor(0x57f287).setFooter({ text: 'APPROVED' });
      await response.update({ embeds: [approvedEmbed], components: [] });
      state.approved = true;
      return 'APPROVED';
    }

    if (response.customId === 'admin_deny') {
      // Open modal for optional denial reason
      const modal = new ModalBuilder()
        .setCustomId('admin_deny_modal')
        .setTitle('Denial Reason')
        .addComponents(
          new ActionRowBuilder().addComponents(
            new TextInputBuilder()
              .setCustomId('reason')
              .setLabel('Why? (optional)')
              .setStyle(TextInputStyle.Paragraph)
              .setRequired(false)
          )
        );

      await response.showModal(modal);

      const modalSubmit = await response.awaitModalSubmit({
        filter: (i) => i.user.id === interaction.user.id,
        time: 120_000,
      });

      const reason = modalSubmit.fields.getTextInputValue('reason') || 'No reason given';
      const deniedEmbed = EmbedBuilder.from(embed).setColor(0xed4245).setFooter({ text: `DENIED: ${reason}` });
      await modalSubmit.update({ embeds: [deniedEmbed], components: [] });
      return `DENIED: ${reason}`;
    }

    // Cancel
    await response.update({ components: [] });
    throw new AdminCancelError();
  } catch (err) {
    if (err instanceof AdminCancelError) throw err;
    await msg.edit({ components: [] }).catch(() => {});
    throw new AdminTimeoutError();
  }
}

// ---------------------------------------------------------------------------
// Discord API tool handlers (pure wrappers)
// ---------------------------------------------------------------------------

function handleListChannels(guild) {
  const channels = guild.channels.cache
    .sort((a, b) => a.position - b.position)
    .map(ch => ({
      id: ch.id,
      name: ch.name,
      type: ChannelType[ch.type] || String(ch.type),
      parentId: ch.parentId || null,
      parentName: ch.parent?.name || null,
      position: ch.position,
    }));
  return JSON.stringify(channels, null, 2);
}

function handleListRoles(guild) {
  const roles = guild.roles.cache
    .sort((a, b) => b.position - a.position)
    .map(r => ({
      id: r.id,
      name: r.name,
      color: r.hexColor,
      memberCount: r.members.size,
      position: r.position,
    }));
  return JSON.stringify(roles, null, 2);
}

function handleGetServerInfo(guild) {
  return JSON.stringify({
    name: guild.name,
    memberCount: guild.memberCount,
    boostLevel: guild.premiumTier,
    boostCount: guild.premiumSubscriptionCount || 0,
    channelCount: guild.channels.cache.size,
    roleCount: guild.roles.cache.size,
  });
}

async function handleReadMessages(guild, input) {
  const channel = guild.channels.cache.get(input.channel_id);
  if (!channel || !channel.isTextBased()) return 'Channel not found or not text-based.';
  const limit = Math.min(Math.max(input.limit || 10, 1), 25);
  const messages = await channel.messages.fetch({ limit });
  const formatted = messages.map(m => ({
    author: m.author.tag,
    content: m.content.slice(0, 500),
    timestamp: m.createdAt.toISOString(),
  }));
  return JSON.stringify(formatted, null, 2);
}

async function handleCreateCategory(guild, input) {
  const opts = { name: input.name, type: ChannelType.GuildCategory };
  if (input.position != null) opts.position = input.position;
  const category = await guild.channels.create(opts);
  return JSON.stringify({ id: category.id, name: category.name });
}

async function handleCreateChannel(guild, input) {
  const type = input.type === 'voice' ? ChannelType.GuildVoice : ChannelType.GuildText;
  const opts = { name: input.name, type };
  if (input.parent_id) opts.parent = input.parent_id;
  if (input.topic && type === ChannelType.GuildText) opts.topic = input.topic;
  const channel = await guild.channels.create(opts);
  return JSON.stringify({ id: channel.id, name: channel.name, parentId: channel.parentId });
}

async function handleSendMessage(guild, input) {
  const channel = guild.channels.cache.get(input.channel_id);
  if (!channel || !channel.isTextBased()) throw new Error('Channel not found or not text-based.');
  const payload = {};
  if (input.content) payload.content = input.content;
  if (input.embed) payload.embeds = [input.embed];
  if (!payload.content && !payload.embeds) throw new Error('Must provide content or embed.');
  const msg = await channel.send(payload);
  return JSON.stringify({ id: msg.id, channelId: msg.channelId });
}

async function handleSetPermissions(guild, input) {
  const channel = guild.channels.cache.get(input.channel_id);
  if (!channel) throw new Error('Channel not found.');

  const overwrites = {};
  if (input.allow && input.allow.length > 0) {
    const flags = input.allow.map(p => PermissionsBitField.Flags[p]).filter(Boolean);
    if (flags.length > 0) overwrites.allow = flags;
  }
  if (input.deny && input.deny.length > 0) {
    const flags = input.deny.map(p => PermissionsBitField.Flags[p]).filter(Boolean);
    if (flags.length > 0) overwrites.deny = flags;
  }

  await channel.permissionOverwrites.edit(input.target_id, overwrites);
  return `Permissions updated for ${input.target_type} ${input.target_id} on #${channel.name}`;
}

// ---------------------------------------------------------------------------
// Custom error classes for flow control
// ---------------------------------------------------------------------------

class AdminCancelError extends Error {
  constructor() { super('Admin cancelled the session.'); this.name = 'AdminCancelError'; }
}

class AdminTimeoutError extends Error {
  constructor() { super('Timed out waiting for admin response (2 minutes). Session ended.'); this.name = 'AdminTimeoutError'; }
}

// ---------------------------------------------------------------------------
// Tool dispatch
// ---------------------------------------------------------------------------

async function dispatchTool(name, input, guild, interaction, state) {
  switch (name) {
    // Read-only
    case 'list_channels': return handleListChannels(guild);
    case 'list_roles': return handleListRoles(guild);
    case 'get_server_info': return handleGetServerInfo(guild);
    case 'read_channel_messages': return await handleReadMessages(guild, input);

    // Interactive
    case 'ask_question': return await handleAskQuestion(interaction, input);
    case 'propose_plan': return await handleProposePlan(interaction, input, state);

    // Execution (gated)
    case 'create_category': {
      state.executionCount++;
      const res = await handleCreateCategory(guild, input);
      state.actions.push(`Created category "${input.name}"`);
      return res;
    }
    case 'create_channel': {
      state.executionCount++;
      const res = await handleCreateChannel(guild, input);
      state.actions.push(`Created ${input.type} channel #${input.name}${input.parent_id ? '' : ' (no category)'}`);
      return res;
    }
    case 'send_message': {
      state.executionCount++;
      const res = await handleSendMessage(guild, input);
      state.actions.push(`Sent message to <#${input.channel_id}>`);
      return res;
    }
    case 'set_channel_permissions': {
      state.executionCount++;
      const res = await handleSetPermissions(guild, input);
      state.actions.push(`Set permissions on <#${input.channel_id}> for ${input.target_type} ${input.target_id}`);
      return res;
    }

    default:
      return `Unknown tool: ${name}`;
  }
}

// ---------------------------------------------------------------------------
// Main agentic loop
// ---------------------------------------------------------------------------

export async function runAdminLoop(guild, interaction, userPrompt) {
  const client = new Anthropic({ apiKey: config.anthropicApiKey });
  const messages = [{ role: 'user', content: userPrompt }];
  const state = {
    approved: false,
    actions: [],
    executionCount: 0,
  };

  for (let turn = 0; turn < config.maxAdminTurns; turn++) {
    const response = await client.messages.create({
      model: config.adminModel,
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      tools: TOOLS,
      messages,
    });

    messages.push({ role: 'assistant', content: response.content });

    // If Claude is done (no tool calls), return the final text
    if (response.stop_reason === 'end_turn') {
      const text = response.content.filter(b => b.type === 'text').map(b => b.text).join('\n');
      return { success: true, summary: text, actions: state.actions };
    }

    // Process tool calls
    const toolResults = [];
    for (const block of response.content) {
      if (block.type !== 'tool_use') continue;

      let result;
      try {
        // Gate execution tools on approval
        if (EXECUTION_TOOLS.has(block.name) && !state.approved) {
          result = 'ERROR: You must call propose_plan and receive APPROVED before executing any changes.';
        } else if (EXECUTION_TOOLS.has(block.name) && state.executionCount >= config.maxAdminExecutions) {
          result = `ERROR: Maximum execution tool calls (${config.maxAdminExecutions}) reached for this session.`;
        } else {
          result = await dispatchTool(block.name, block.input, guild, interaction, state);
        }
      } catch (err) {
        // AdminCancelError and AdminTimeoutError propagate up to end the session
        if (err instanceof AdminCancelError || err instanceof AdminTimeoutError) {
          return { success: false, error: err.message, actions: state.actions };
        }
        result = `Error: ${err.message}`;
      }

      toolResults.push({
        type: 'tool_result',
        tool_use_id: block.id,
        content: typeof result === 'string' ? result : JSON.stringify(result),
      });
    }

    messages.push({ role: 'user', content: toolResults });

    // Status update on the deferred reply
    await interaction.editReply({
      embeds: [
        new EmbedBuilder()
          .setTitle('Admin Assistant')
          .setDescription(`Working... (turn ${turn + 1}/${config.maxAdminTurns})`)
          .setColor(0x5865f2),
      ],
    }).catch(() => {});
  }

  return { success: false, error: `Reached maximum turns (${config.maxAdminTurns}).`, actions: state.actions };
}
