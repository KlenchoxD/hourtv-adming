
-- Notifica cada transición de salud concluyente sin generar duplicados para
-- el mismo servidor mientras la notificación siga abierta.
create or replace function public.record_source_health_notification()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  next_type text;
  next_message text;
begin
  if new.health_status is not distinct from old.health_status then
    return new;
  end if;

  next_type := case new.health_status
    when 'suspected_down' then 'suspected_down'
    when 'down' then 'confirmed_down'
    when 'recovered' then 'recovered'
    else null
  end;

  if next_type is null then
    return new;
  end if;

  next_message := case next_type
    when 'suspected_down' then format('El servidor %s presenta fallos; puedes comprobarlo o buscar un reemplazo.', new.name)
    when 'confirmed_down' then format('El servidor %s está caído. Puedes reemplazarlo por una fuente de confianza alta.', new.name)
    else format('El servidor %s volvió a responder correctamente.', new.name)
  end;

  if not exists (
    select 1
    from public.admin_notifications n
    where n.source_id = new.id
      and n.notification_type = next_type
      and n.status in ('open', 'processing')
  ) then
    insert into public.admin_notifications(notification_type, source_id, message)
    values (next_type, new.id, next_message);
  end if;

  return new;
end;
$$;

drop trigger if exists sources_health_notification on public.sources;
create trigger sources_health_notification
after update of health_status on public.sources
for each row execute function public.record_source_health_notification();

-- Recupera avisos para servidores que ya estaban marcados antes de instalar
-- el trigger, sin duplicar notificaciones abiertas.
insert into public.admin_notifications(notification_type, source_id, message)
select
  case s.health_status when 'down' then 'confirmed_down' else 'suspected_down' end,
  s.id,
  case s.health_status
    when 'down' then format('El servidor %s está caído. Puedes reemplazarlo por una fuente de confianza alta.', s.name)
    else format('El servidor %s presenta fallos; puedes comprobarlo o buscar un reemplazo.', s.name)
  end
from public.sources s
where s.health_status in ('down', 'suspected_down')
  and not exists (
    select 1
    from public.admin_notifications n
    where n.source_id = s.id
      and n.notification_type = case s.health_status when 'down' then 'confirmed_down' else 'suspected_down' end
      and n.status in ('open', 'processing')
  );
