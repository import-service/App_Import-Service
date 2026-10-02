-- Статусы верхнего уровня по канону: closed / cancelled.
-- Без них архивация (status=closed) не находит заявки.

ALTER TABLE customs_requests
  MODIFY COLUMN status ENUM(
    'new',
    'on_review',
    'in_progress',
    'in_transit',
    'delivered',
    'closed',
    'cancelled'
  ) NOT NULL DEFAULT 'new';
