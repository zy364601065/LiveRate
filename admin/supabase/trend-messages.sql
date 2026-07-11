create table if not exists public.stats_trend_messages (
  id uuid primary key,
  scope text not null check (scope in ('global', 'user')),
  user_id uuid null references auth.users(id) on delete cascade,
  trigger_type text not null check (trigger_type in ('consecutive_loss', 'consecutive_profit', 'loss_to_profit', 'profit_to_loss')),
  message text not null check (char_length(message) between 1 and 80),
  is_enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stats_trend_messages_scope_user_check check (
    (scope = 'global' and user_id is null) or (scope = 'user' and user_id is not null)
  )
);

create index if not exists stats_trend_messages_visibility_idx
  on public.stats_trend_messages (scope, user_id, trigger_type, is_enabled, sort_order, created_at desc);

alter table public.stats_trend_messages enable row level security;
grant select on public.stats_trend_messages to authenticated;

drop policy if exists "Users can read visible trend messages" on public.stats_trend_messages;
create policy "Users can read visible trend messages"
on public.stats_trend_messages for select to authenticated
using (is_enabled = true and (scope = 'global' or user_id = (select auth.uid())));

insert into public.stats_trend_messages (id, scope, trigger_type, message, sort_order) values
('10000000-0000-4000-8000-000000000001','global','consecutive_loss','绿绿更健康，只要我不卖，这就只是数字的艺术。',0),
('10000000-0000-4000-8000-000000000002','global','consecutive_loss','行情总在绝望中诞生，在半信半疑中成长。再坚持一下！',1),
('10000000-0000-4000-8000-000000000003','global','consecutive_loss','最近的股市/汇市就像我的感情生活，不仅绿，还跌跌不休。',2),
('10000000-0000-4000-8000-000000000004','global','consecutive_loss','恭喜你成功避开了所有上涨的资产，这也是一种百里挑一的技术。',3),
('20000000-0000-4000-8000-000000000001','global','consecutive_profit','你最近的手感热得发烫！巴菲特看了都要给你点个赞。',0),
('20000000-0000-4000-8000-000000000002','global','consecutive_profit','持续复利是世界第八大奇迹，你正在亲手创造这个奇迹。',1),
('20000000-0000-4000-8000-000000000003','global','consecutive_profit','账户又新高了，今晚不考虑给自己加个鸡腿或者买杯奶茶吗？',2),
('20000000-0000-4000-8000-000000000004','global','consecutive_profit','顺风局请保持冷静，别忘了设置好你的分批止盈点哦。',3),
('30000000-0000-4000-8000-000000000001','global','loss_to_profit','阳线改变信仰！昨天的阴霾一扫而空，属于你的主场回来了！',0),
('30000000-0000-4000-8000-000000000002','global','loss_to_profit','触底反弹！我就知道你有一颗守得云开见月明的大心脏。',1),
('30000000-0000-4000-8000-000000000003','global','loss_to_profit','成功收复失地！这一波反转，堪称教科书级别的持股定力。',2),
('30000000-0000-4000-8000-000000000004','global','loss_to_profit','看吧，时间总会奖励那些在暴风雨中不曾离场的人。',3),
('40000000-0000-4000-8000-000000000001','global','profit_to_loss','今天只是利润的小小回撤，不经历风雨怎么见彩虹？',0),
('40000000-0000-4000-8000-000000000002','global','profit_to_loss','偶尔交点学费是正常的，胜败乃兵家常事，稳住心态！',1),
('40000000-0000-4000-8000-000000000003','global','profit_to_loss','昨天的盈利是底气，今天的调整是伏笔。睡一觉，明天又是新的一天。',2),
('40000000-0000-4000-8000-000000000004','global','profit_to_loss','市场在和你开个小玩笑，别影响了今天吃晚饭的好心情。',3)
on conflict (id) do update set
  trigger_type = excluded.trigger_type,
  message = excluded.message,
  sort_order = excluded.sort_order,
  updated_at = now();
