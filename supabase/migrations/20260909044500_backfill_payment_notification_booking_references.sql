update public.notifications n
set reference_id = p.booking_id,
    reference_type = 'booking'
from public.payments p
where n.reference_type = 'payment'
  and n.reference_id = p.id
  and p.booking_id is not null;
