-- LAKOL : schéma complet de la base (schema + migrations 1 à 6), pour recréer la base dans un NOUVEAU projet Supabase.
-- À lancer dans Supabase > SQL Editor d'un projet vide. Régénéré à chaque nouvelle migration.

-- ================= schema.sql =================
-- =====================================================
-- Gestion d'école privée : schéma MVP (Supabase / Postgres)
-- Colle tout ce fichier dans Supabase > SQL Editor > Run
-- =====================================================

-- ---------- TABLES ----------

create table schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  phone text,
  created_at timestamptz default now()
);

-- Un profil par utilisateur connecté (lié à Supabase Auth)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  school_id uuid references schools(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('admin', 'teacher', 'parent')),
  phone text,
  created_at timestamptz default now()
);

create table classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,                -- ex. 6e A
  school_year text not null,         -- ex. 2026-2027
  created_at timestamptz default now()
);

create table students (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid references classes(id) on delete set null,
  first_name text not null,
  last_name text not null,
  birth_date date,
  matricule text,
  created_at timestamptz default now(),
  unique (school_id, matricule)
);

create table parents_students (
  parent_id uuid not null references profiles(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  primary key (parent_id, student_id)
);

create table subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  name text not null,
  coefficient numeric(4,2) not null default 1
);

-- Qui enseigne quelle matière à quelle classe
create table teaching (
  teacher_id uuid not null references profiles(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  primary key (teacher_id, class_id, subject_id)
);

create table grades (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  term int not null check (term between 1 and 3),   -- trimestre
  kind text not null check (kind in ('devoir', 'composition')),
  score numeric(4,2) not null check (score between 0 and 20),
  created_by uuid references profiles(id),
  created_at timestamptz default now()
);

create table fees (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid references classes(id) on delete cascade,
  label text not null,               -- ex. Scolarité, Inscription
  amount integer not null            -- en FCFA
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  fee_id uuid references fees(id) on delete set null,
  amount integer not null,           -- en FCFA
  method text not null check (method in ('moov', 'airtel', 'orange', 'nita', 'cash')),
  reference text,
  paid_at timestamptz default now()
);

-- ---------- INDEX ----------
create index on students (school_id, class_id);
create index on grades (student_id, subject_id, term);
create index on payments (student_id);

-- ---------- FONCTIONS UTILITAIRES (pour la sécurité) ----------
-- security definer = évite les boucles infinies dans les règles RLS

create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid()
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

-- ---------- SÉCURITÉ : ROW LEVEL SECURITY ----------
-- Règle d'or : un utilisateur ne voit que les données de SON école.

alter table schools enable row level security;
alter table profiles enable row level security;
alter table classes enable row level security;
alter table students enable row level security;
alter table parents_students enable row level security;
alter table subjects enable row level security;
alter table teaching enable row level security;
alter table grades enable row level security;
alter table fees enable row level security;
alter table payments enable row level security;

-- schools
create policy "voir son école" on schools
  for select using (id = my_school_id());

-- profiles
create policy "voir les profils de son école" on profiles
  for select using (school_id = my_school_id() or id = auth.uid());
create policy "admin gère les profils" on profiles
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- classes, subjects, fees : tout le monde de l'école lit, l'admin écrit
create policy "lire classes" on classes
  for select using (school_id = my_school_id());
create policy "admin écrit classes" on classes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create policy "lire matières" on subjects
  for select using (school_id = my_school_id());
create policy "admin écrit matières" on subjects
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create policy "lire frais" on fees
  for select using (school_id = my_school_id());
create policy "admin écrit frais" on fees
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- students : admin et enseignants voient tous les élèves de l'école,
-- un parent voit seulement ses enfants
create policy "staff voit élèves" on students
  for select using (
    school_id = my_school_id() and my_role() in ('admin', 'teacher')
  );
create policy "parent voit ses enfants" on students
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = students.id and ps.parent_id = auth.uid()
    )
  );
create policy "admin écrit élèves" on students
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- parents_students
create policy "voir liens parents" on parents_students
  for select using (
    parent_id = auth.uid()
    or (my_role() in ('admin', 'teacher')
        and exists (select 1 from students s
                    where s.id = student_id and s.school_id = my_school_id()))
  );
create policy "admin écrit liens parents" on parents_students
  for all using (
    my_role() = 'admin'
    and exists (select 1 from students s
                where s.id = student_id and s.school_id = my_school_id())
  )
  with check (
    my_role() = 'admin'
    and exists (select 1 from students s
                where s.id = student_id and s.school_id = my_school_id())
  );

-- teaching
create policy "voir affectations" on teaching
  for select using (
    teacher_id = auth.uid()
    or (my_role() = 'admin'
        and exists (select 1 from classes c
                    where c.id = class_id and c.school_id = my_school_id()))
  );
create policy "admin écrit affectations" on teaching
  for all using (
    my_role() = 'admin'
    and exists (select 1 from classes c
                where c.id = class_id and c.school_id = my_school_id())
  )
  with check (
    my_role() = 'admin'
    and exists (select 1 from classes c
                where c.id = class_id and c.school_id = my_school_id())
  );

-- grades
create policy "staff voit notes" on grades
  for select using (
    school_id = my_school_id() and my_role() in ('admin', 'teacher')
  );
create policy "parent voit notes de ses enfants" on grades
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = grades.student_id and ps.parent_id = auth.uid()
    )
  );
create policy "admin écrit notes" on grades
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
-- Un enseignant écrit seulement les notes de SES classes/matières
create policy "enseignant ajoute notes" on grades
  for insert with check (
    school_id = my_school_id()
    and my_role() = 'teacher'
    and exists (
      select 1 from teaching t
      join students s on s.class_id = t.class_id
      where t.teacher_id = auth.uid()
        and t.subject_id = grades.subject_id
        and s.id = grades.student_id
    )
  );
create policy "enseignant modifie ses notes" on grades
  for update using (
    school_id = my_school_id() and my_role() = 'teacher' and created_by = auth.uid()
  );

-- payments : admin gère, parent voit les paiements de ses enfants
create policy "admin gère paiements" on payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "parent voit paiements de ses enfants" on payments
  for select using (
    my_role() = 'parent'
    and exists (
      select 1 from parents_students ps
      where ps.student_id = payments.student_id and ps.parent_id = auth.uid()
    )
  );

-- ---------- VUE : MOYENNES PAR ÉLÈVE, MATIÈRE ET TRIMESTRE ----------
-- Calculées à la demande, jamais stockées.
-- security_invoker = les règles RLS s'appliquent aussi à la vue.
create or replace view student_subject_averages
with (security_invoker = true) as
select
  g.student_id,
  g.subject_id,
  g.term,
  round(avg(g.score), 2) as average
from grades g
group by g.student_id, g.subject_id, g.term;

-- ================= lakol_migration_1.sql =================
-- =====================================================
-- LAKOL : migration 1
-- Rôles (directeur / professeur / parent), classes créées par les
-- profs, présences, comportement, emploi du temps, inscription par code.
-- Supabase > SQL Editor > New query > colle tout > Run
-- (dans la base, le rôle "admin" = Directeur dans l'application)
-- =====================================================

-- ---------- 1. NOUVELLES COLONNES ----------
alter table classes
  add column if not exists created_by uuid references profiles(id) on delete set null;

-- Code donné aux parents pour rejoindre leur enfant
alter table students
  add column if not exists access_code text unique
  default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));

-- ---------- 2. CODE SECRET DE L'ÉCOLE (visible seulement par le directeur) ----------
create table if not exists school_secrets (
  school_id uuid primary key references schools(id) on delete cascade,
  join_code text not null unique
    default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6))
);
insert into school_secrets (school_id) select id from schools on conflict do nothing;

-- ---------- 3. NOUVELLES TABLES ----------
create table if not exists timetable (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid references subjects(id) on delete set null,
  teacher_id uuid references profiles(id) on delete set null,
  day int not null check (day between 1 and 6),       -- 1 = lundi ... 6 = samedi
  start_time time not null,
  end_time time not null,
  room text,
  created_at timestamptz default now()
);

create table if not exists attendance (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  date date not null default current_date,
  status text not null check (status in ('present', 'absent', 'late')),
  note text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique (student_id, class_id, date, created_by)
);

create table if not exists behavior_notes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  student_id uuid not null references students(id) on delete cascade,
  date date not null default current_date,
  kind text not null check (kind in
    ('bavardage', 'perturbation', 'retard', 'oubli_materiel', 'insolence', 'positif', 'autre')),
  comment text,
  visible_to_parent boolean not null default true,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now()
);

create index if not exists attendance_class_date on attendance (class_id, date);
create index if not exists behavior_student on behavior_notes (student_id);
create index if not exists timetable_class on timetable (class_id);

-- ---------- 4. FONCTIONS UTILITAIRES (évitent les boucles de sécurité) ----------
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid()
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function public.is_parent_of(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from parents_students where student_id = sid and parent_id = auth.uid()
  )
$$;

create or replace function public.student_in_my_school(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from students where id = sid and school_id = my_school_id())
$$;

create or replace function public.class_in_my_school(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from classes where id = cid and school_id = my_school_id())
$$;

-- Le prof enseigne dans la classe, ou l'a créée
create or replace function public.teaches_class(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from teaching where teacher_id = auth.uid() and class_id = cid)
      or exists (select 1 from classes where id = cid and created_by = auth.uid())
$$;

create or replace function public.teaches_student(sid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from students s where s.id = sid and teaches_class(s.class_id)
  )
$$;

create or replace function public.teaches_subject_to(sid uuid, subj uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from teaching t
    join students s on s.class_id = t.class_id
    where t.teacher_id = auth.uid() and t.subject_id = subj and s.id = sid
  )
$$;

create or replace function public.parent_has_child_in_class(cid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from parents_students ps
    join students s on s.id = ps.student_id
    where ps.parent_id = auth.uid() and s.class_id = cid
  )
$$;

-- ---------- 5. INSCRIPTION PAR RÔLE ----------
-- À la création d'un compte, on lit les infos données à l'inscription.
--  admin   : crée une nouvelle école
--  teacher : rejoint une école avec le code de l'école
--  parent  : rejoint un enfant avec le code de l'élève
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role text := meta->>'role';
  v_name text := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(coalesce(new.email, 'utilisateur'), '@', 1));
  v_school uuid;
  v_student uuid;
begin
  if v_role = 'admin' then
    insert into schools (name, city)
    values (coalesce(nullif(trim(meta->>'school_name'), ''), 'Mon école'), nullif(trim(meta->>'city'), ''))
    returning id into v_school;
    insert into school_secrets (school_id) values (v_school);
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'admin');

  elsif v_role = 'teacher' then
    select school_id into v_school from school_secrets
      where join_code = upper(trim(meta->>'school_code'));
    if v_school is null then
      raise exception 'Code école invalide';
    end if;
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'teacher');

  elsif v_role = 'parent' then
    select id, school_id into v_student, v_school from students
      where access_code = upper(trim(meta->>'student_code'));
    if v_student is null then
      raise exception 'Code élève invalide';
    end if;
    insert into profiles (id, school_id, full_name, role) values (new.id, v_school, v_name, 'parent');
    insert into parents_students (parent_id, student_id) values (new.id, v_student);
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Un parent ajoute un 2e enfant avec son code
create or replace function public.link_child(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_student uuid;
  v_school uuid;
begin
  if my_role() is distinct from 'parent' then
    raise exception 'Non autorisé';
  end if;
  select id, school_id into v_student, v_school from students
    where access_code = upper(trim(p_code));
  if v_student is null or v_school <> my_school_id() then
    raise exception 'Code invalide';
  end if;
  insert into parents_students (parent_id, student_id)
  values (auth.uid(), v_student) on conflict do nothing;
end $$;

-- Un prof (ou directeur) crée une classe, ses matières et ses élèves d'un coup
-- p_students : une ligne par élève, au format "Nom Prénom"
create or replace function public.create_class(
  p_name text, p_year text, p_subject_ids uuid[], p_students text[]
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_class uuid;
  v_subject uuid;
  v_line text;
  v_last text;
  v_first text;
begin
  if my_role() not in ('teacher', 'admin') then
    raise exception 'Non autorisé';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Donne un nom à la classe';
  end if;

  insert into classes (school_id, name, school_year, created_by)
  values (v_school, trim(p_name), coalesce(nullif(trim(p_year), ''), '2026-2027'), auth.uid())
  returning id into v_class;

  if p_subject_ids is not null then
    foreach v_subject in array p_subject_ids loop
      if exists (select 1 from subjects where id = v_subject and school_id = v_school) then
        insert into teaching (teacher_id, class_id, subject_id)
        values (auth.uid(), v_class, v_subject) on conflict do nothing;
      end if;
    end loop;
  end if;

  if p_students is not null then
    foreach v_line in array p_students loop
      v_line := trim(v_line);
      if v_line <> '' then
        v_last := split_part(v_line, ' ', 1);
        v_first := trim(substr(v_line, length(v_last) + 1));
        insert into students (school_id, class_id, last_name, first_name)
        values (v_school, v_class, v_last, v_first);
      end if;
    end loop;
  end if;

  return v_class;
end $$;

-- ---------- 6. RÈGLES DE SÉCURITÉ (on repart de zéro) ----------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('schools', 'profiles', 'classes', 'subjects', 'students',
                        'parents_students', 'teaching', 'grades')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table school_secrets enable row level security;
alter table timetable enable row level security;
alter table attendance enable row level security;
alter table behavior_notes enable row level security;

-- schools / school_secrets
create policy "schools_select" on schools
  for select using (id = my_school_id());
create policy "secrets_admin" on school_secrets
  for select using (school_id = my_school_id() and my_role() = 'admin');

-- profiles
create policy "profiles_self" on profiles
  for select using (id = auth.uid());
create policy "profiles_admin_select" on profiles
  for select using (my_role() = 'admin' and school_id = my_school_id());
create policy "profiles_admin_write" on profiles
  for all using (my_role() = 'admin' and school_id = my_school_id())
  with check (my_role() = 'admin' and school_id = my_school_id());

-- classes
create policy "classes_select" on classes
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(id))
      or (my_role() = 'parent' and parent_has_child_in_class(id))
    )
  );
create policy "classes_admin_write" on classes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "classes_teacher_update" on classes
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "classes_teacher_delete" on classes
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- subjects : tout le monde lit, prof et directeur ajoutent, directeur gère
create policy "subjects_select" on subjects
  for select using (school_id = my_school_id());
create policy "subjects_insert" on subjects
  for insert with check (school_id = my_school_id() and my_role() in ('admin', 'teacher'));
create policy "subjects_admin_all" on subjects
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

-- teaching
create policy "teaching_select" on teaching
  for select using (
    teacher_id = auth.uid()
    or (my_role() = 'admin' and class_in_my_school(class_id))
  );
create policy "teaching_teacher_insert" on teaching
  for insert with check (
    my_role() = 'teacher' and teacher_id = auth.uid() and teaches_class(class_id)
  );
create policy "teaching_teacher_delete" on teaching
  for delete using (my_role() = 'teacher' and teacher_id = auth.uid());
create policy "teaching_admin_all" on teaching
  for all using (my_role() = 'admin' and class_in_my_school(class_id))
  with check (my_role() = 'admin' and class_in_my_school(class_id));

-- students
create policy "students_select" on students
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and is_parent_of(id))
  );
create policy "students_admin_write" on students
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "students_teacher_insert" on students
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id)
  );
create policy "students_teacher_update" on students
  for update using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and teaches_class(class_id));
create policy "students_teacher_delete" on students
  for delete using (my_role() = 'teacher' and teaches_class(class_id));

-- parents_students
create policy "ps_select" on parents_students
  for select using (
    parent_id = auth.uid()
    or (my_role() = 'admin' and student_in_my_school(student_id))
  );
create policy "ps_admin_write" on parents_students
  for all using (my_role() = 'admin' and student_in_my_school(student_id))
  with check (my_role() = 'admin' and student_in_my_school(student_id));

-- grades
create policy "grades_select" on grades
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_student(student_id))
    or (my_role() = 'parent' and is_parent_of(student_id))
  );
create policy "grades_admin_write" on grades
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "grades_teacher_insert" on grades
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_subject_to(student_id, subject_id)
  );
create policy "grades_teacher_update" on grades
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "grades_teacher_delete" on grades
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- timetable
create policy "timetable_select" on timetable
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(class_id))
      or (my_role() = 'parent' and parent_has_child_in_class(class_id))
    )
  );
create policy "timetable_admin_write" on timetable
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "timetable_teacher_write" on timetable
  for all using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id));

-- attendance
create policy "attendance_select" on attendance
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and is_parent_of(student_id))
  );
create policy "attendance_admin_write" on attendance
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "attendance_teacher_insert" on attendance
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_class(class_id)
  );
create policy "attendance_teacher_update" on attendance
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "attendance_teacher_delete" on attendance
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- behavior_notes (le parent ne voit que les notes marquées "visibles")
create policy "behavior_select" on behavior_notes
  for select using (
    (school_id = my_school_id() and my_role() = 'admin')
    or (my_role() = 'teacher' and teaches_class(class_id))
    or (my_role() = 'parent' and visible_to_parent and is_parent_of(student_id))
  );
create policy "behavior_admin_write" on behavior_notes
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');
create policy "behavior_teacher_insert" on behavior_notes
  for insert with check (
    school_id = my_school_id() and my_role() = 'teacher'
    and created_by = auth.uid() and teaches_class(class_id)
  );
create policy "behavior_teacher_update" on behavior_notes
  for update using (my_role() = 'teacher' and created_by = auth.uid());
create policy "behavior_teacher_delete" on behavior_notes
  for delete using (my_role() = 'teacher' and created_by = auth.uid());

-- ================= lakol_migration_2.sql =================
-- =====================================================
-- LAKOL : migration 2
-- Directeur (vue d'ensemble, professeurs, salaires), scolarité
-- réservée au directeur et aux parents, comptes désactivables.
-- Prérequis : lakol_migration_1.sql déjà lancée.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. COMPTES : ACTIF / EMAIL ----------
alter table profiles add column if not exists active boolean not null default true;
alter table profiles add column if not exists email text;

update profiles p set email = u.email
from auth.users u
where u.id = p.id and p.email is null;

-- Un compte désactivé n'a plus ni rôle ni école : il ne voit plus rien.
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid() and active
$$;

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active
$$;

create or replace function public.profile_in_my_school(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = pid and school_id = my_school_id())
$$;

-- L'inscription enregistre aussi l'email
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role text := meta->>'role';
  v_name text := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(coalesce(new.email, 'utilisateur'), '@', 1));
  v_school uuid;
  v_student uuid;
begin
  if v_role = 'admin' then
    insert into schools (name, city)
    values (coalesce(nullif(trim(meta->>'school_name'), ''), 'Mon école'), nullif(trim(meta->>'city'), ''))
    returning id into v_school;
    insert into school_secrets (school_id) values (v_school);
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'admin', new.email);

  elsif v_role = 'teacher' then
    select school_id into v_school from school_secrets
      where join_code = upper(trim(meta->>'school_code'));
    if v_school is null then
      raise exception 'Code école invalide';
    end if;
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'teacher', new.email);

  elsif v_role = 'parent' then
    select id, school_id into v_student, v_school from students
      where access_code = upper(trim(meta->>'student_code'));
    if v_student is null then
      raise exception 'Code élève invalide';
    end if;
    insert into profiles (id, school_id, full_name, role, email)
    values (new.id, v_school, v_name, 'parent', new.email);
    insert into parents_students (parent_id, student_id) values (new.id, v_student);
  end if;

  return new;
end $$;

-- ---------- 2. SALAIRES ----------
create table if not exists staff_pay (
  teacher_id uuid primary key references profiles(id) on delete cascade,
  school_id uuid not null references schools(id) on delete cascade,
  monthly_salary integer not null default 0 check (monthly_salary >= 0)
);

create table if not exists salary_payments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  teacher_id uuid not null references profiles(id) on delete cascade,
  month text not null check (month ~ '^[0-9]{4}-[0-9]{2}$'),   -- ex. 2026-11
  amount integer not null check (amount > 0),
  method text not null default 'cash'
    check (method in ('moov', 'airtel', 'orange', 'nita', 'cash', 'virement')),
  note text,
  paid_at timestamptz default now(),
  created_by uuid references profiles(id) on delete set null
);
create index if not exists salary_payments_teacher on salary_payments (teacher_id, month);

alter table staff_pay enable row level security;
alter table salary_payments enable row level security;
alter table fees enable row level security;
alter table payments enable row level security;

-- ---------- 3. RÈGLES DE SÉCURITÉ ----------
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('fees', 'payments', 'staff_pay', 'salary_payments')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- Frais de scolarité : directeur gère, parents voient ceux de la classe de leur enfant.
-- Les professeurs n'y ont PAS accès.
create policy "fees_admin" on fees
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin'
    and (class_id is null or class_in_my_school(class_id))
  );
create policy "fees_parent" on fees
  for select using (
    my_role() = 'parent' and class_id is not null and parent_has_child_in_class(class_id)
  );

-- Paiements de scolarité : directeur gère, parents voient ceux de leurs enfants.
create policy "payments_admin" on payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and student_in_my_school(student_id)
  );
create policy "payments_parent" on payments
  for select using (my_role() = 'parent' and is_parent_of(student_id));

-- Salaires : directeur gère, chaque professeur voit uniquement le sien.
create policy "staffpay_admin" on staff_pay
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and profile_in_my_school(teacher_id)
  );
create policy "staffpay_self" on staff_pay
  for select using (teacher_id = auth.uid());

create policy "salarypay_admin" on salary_payments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (
    school_id = my_school_id() and my_role() = 'admin' and profile_in_my_school(teacher_id)
  );
create policy "salarypay_self" on salary_payments
  for select using (teacher_id = auth.uid());

-- ---------- 4. FONCTIONS POUR LE DIRECTEUR ----------

-- Nouveau code d'école (si l'ancien a été partagé trop largement)
create or replace function public.regenerate_join_code()
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
  update school_secrets set join_code = v_code where school_id = my_school_id();
  return v_code;
end $$;

-- Situation de scolarité de chaque élève (dû, payé)
create or replace function public.student_balances()
returns table (
  student_id uuid, first_name text, last_name text,
  class_id uuid, class_name text, due bigint, paid bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  return query
  select s.id, s.first_name, s.last_name, s.class_id, c.name,
    coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id), 0)::bigint,
    coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0)::bigint
  from students s
  left join classes c on c.id = s.class_id
  where s.school_id = my_school_id()
  order by s.last_name, s.first_name;
end $$;

-- Vue d'ensemble de l'école. p_term = 1, 2, 3 ou null (tous les trimestres).
-- Moyenne d'une matière = (moyenne des devoirs + composition) / 2, puis
-- moyenne générale pondérée par les coefficients (comme le bulletin).
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;

  with subj as (
    select g.student_id, g.subject_id, sb.coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then (avg(g.score) filter (where g.kind = 'devoir')
               + avg(g.score) filter (where g.kind = 'composition')) / 2
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, sb.coefficient
  ),
  stu as (
    select student_id,
      sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < 10) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles
                 where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce(
      (select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5
      ) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school
        order by p.paid_at desc limit 6
      ) y), '[]'::jsonb)
  ) into v_result;

  return v_result;
end $$;

-- ---------- 5. DEVOIRS ET EXAMENS À VENIR (planning de classe) ----------
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid references subjects(id) on delete set null,
  kind text not null default 'devoir' check (kind in ('devoir', 'examen', 'composition')),
  title text not null,
  due_date date not null,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);
create index if not exists assignments_class on assignments (class_id, due_date);
alter table assignments enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'assignments'
  loop execute format('drop policy %I on public.assignments', r.policyname); end loop;
end $$;

create policy "assign_select" on assignments
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or (my_role() = 'teacher' and teaches_class(class_id))
      or (my_role() = 'parent' and parent_has_child_in_class(class_id))
    )
  );
create policy "assign_admin_write" on assignments
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin' and class_in_my_school(class_id));
create policy "assign_teacher_write" on assignments
  for all using (my_role() = 'teacher' and teaches_class(class_id))
  with check (school_id = my_school_id() and my_role() = 'teacher' and teaches_class(class_id));

-- ================= lakol_migration_3.sql =================
-- =====================================================
-- LAKOL : migration 3
-- Le directeur ne touche plus aux notes, classes uniques et visibles
-- par tous, matières modifiables, frais généraux, plan des devoirs.
-- Prérequis : migrations 1 et 2 déjà lancées.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. LE DIRECTEUR NE MODIFIE PLUS LES NOTES (lecture seule) ----------
drop policy if exists "grades_admin_write" on grades;

-- ---------- 2. CLASSES : UNE SEULE "3e B" PAR ÉCOLE ET PAR ANNÉE ----------
drop index if exists classes_unique_name;
do $$
begin
  create unique index if not exists classes_unique_name
    on classes (school_id, lower(regexp_replace(trim(name), '\s+', ' ', 'g')), school_year);
exception when others then
  raise notice 'Des classes en double existent déjà : supprime les doublons puis relance cette migration.';
end $$;

-- Toutes les classes de l'école sont visibles par le directeur et les professeurs
-- (pour pouvoir rejoindre une classe existante). Le parent ne voit que celles de ses enfants.
drop policy if exists "classes_select" on classes;
create policy "classes_select" on classes
  for select using (
    school_id = my_school_id() and (
      my_role() in ('admin', 'teacher')
      or (my_role() = 'parent' and parent_has_child_in_class(id))
    )
  );

-- ---------- 3. MATIÈRES ET PLAN DE CLASSE ----------
alter table subjects add column if not exists created_by uuid references profiles(id) on delete set null;
alter table subjects alter column created_by set default auth.uid();

drop policy if exists "subjects_update_own" on subjects;
create policy "subjects_update_own" on subjects
  for update using (my_role() = 'teacher' and created_by = auth.uid())
  with check (school_id = my_school_id());

-- Combien de devoirs / compositions le professeur prévoit par trimestre
alter table teaching add column if not exists devoirs_per_term int not null default 2;
alter table teaching add column if not exists compositions_per_term int not null default 1;
drop policy if exists "teaching_teacher_update" on teaching;
create policy "teaching_teacher_update" on teaching
  for update using (my_role() = 'teacher' and teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

-- Chapitres (facultatif) et trimestre pour chaque devoir / examen
alter table assignments add column if not exists chapters text;
alter table assignments add column if not exists term int check (term between 1 and 3);

-- Rejoindre une classe qui existe déjà avec ses matières
create or replace function public.join_class(p_class_id uuid, p_subject_ids uuid[])
returns void language plpgsql security definer set search_path = public as $$
declare v_subject uuid;
begin
  if my_role() is distinct from 'teacher' then raise exception 'Non autorisé'; end if;
  if not class_in_my_school(p_class_id) then raise exception 'Classe introuvable'; end if;
  if p_subject_ids is null or array_length(p_subject_ids, 1) is null then
    raise exception 'Choisis au moins une matière';
  end if;
  foreach v_subject in array p_subject_ids loop
    if exists (select 1 from subjects where id = v_subject and school_id = my_school_id()) then
      insert into teaching (teacher_id, class_id, subject_id)
      values (auth.uid(), p_class_id, v_subject) on conflict do nothing;
    end if;
  end loop;
end $$;

-- Supprimer une matière (seulement si elle est à moi et qu'aucune note / autre prof ne l'utilise)
create or replace function public.delete_subject(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_creator uuid;
begin
  select created_by into v_creator from subjects where id = p_id and school_id = my_school_id();
  if not found then raise exception 'Matière introuvable'; end if;
  if not (my_role() = 'admin' or v_creator = auth.uid()) then
    raise exception 'Tu peux seulement supprimer les matières que tu as créées';
  end if;
  if exists (select 1 from grades where subject_id = p_id) then
    raise exception 'Cette matière a déjà des notes : retire-la seulement de ta classe';
  end if;
  if exists (select 1 from teaching where subject_id = p_id and teacher_id <> auth.uid()) then
    raise exception 'Un autre professeur enseigne cette matière : retire-la seulement de ta classe';
  end if;
  delete from subjects where id = p_id;
end $$;

-- Un message clair si la classe existe déjà
create or replace function public.create_class(
  p_name text, p_year text, p_subject_ids uuid[], p_students text[]
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_class uuid;
  v_subject uuid;
  v_line text; v_last text; v_first text;
begin
  if my_role() not in ('teacher', 'admin') then raise exception 'Non autorisé'; end if;
  if coalesce(trim(p_name), '') = '' then raise exception 'Donne un nom à la classe'; end if;
  begin
    insert into classes (school_id, name, school_year, created_by)
    values (v_school, regexp_replace(trim(p_name), '\s+', ' ', 'g'), coalesce(nullif(trim(p_year), ''), '2026-2027'), auth.uid())
    returning id into v_class;
  exception when unique_violation then
    raise exception 'Cette classe existe déjà dans l''école : rejoins-la au lieu de la recréer';
  end;
  if p_subject_ids is not null then
    foreach v_subject in array p_subject_ids loop
      if exists (select 1 from subjects where id = v_subject and school_id = v_school) then
        insert into teaching (teacher_id, class_id, subject_id)
        values (auth.uid(), v_class, v_subject) on conflict do nothing;
      end if;
    end loop;
  end if;
  if p_students is not null then
    foreach v_line in array p_students loop
      v_line := trim(v_line);
      if v_line <> '' then
        v_last := split_part(v_line, ' ', 1);
        v_first := trim(substr(v_line, length(v_last) + 1));
        insert into students (school_id, class_id, last_name, first_name)
        values (v_school, v_class, v_last, v_first);
      end if;
    end loop;
  end if;
  return v_class;
end $$;

-- ---------- 4. FRAIS : GÉNÉRAUX (class_id vide = toutes les classes) + SPÉCIFIQUES ----------
-- Un frais général s'applique automatiquement à toute classe, même créée plus tard.
drop policy if exists "fees_parent" on fees;
create policy "fees_parent" on fees
  for select using (
    my_role() = 'parent' and school_id = my_school_id()
    and (class_id is null or parent_has_child_in_class(class_id))
  );

-- Soldes et tableau de bord : ajoutent les frais généraux
-- Situation de scolarité de chaque élève (dû, payé)
create or replace function public.student_balances()
returns table (
  student_id uuid, first_name text, last_name text,
  class_id uuid, class_name text, due bigint, paid bigint
)
language plpgsql stable security definer set search_path = public as $$
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;
  return query
  select s.id, s.first_name, s.last_name, s.class_id, c.name,
    coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0)::bigint,
    coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0)::bigint
  from students s
  left join classes c on c.id = s.class_id
  where s.school_id = my_school_id()
  order by s.last_name, s.first_name;
end $$;

-- Vue d'ensemble de l'école. p_term = 1, 2, 3 ou null (tous les trimestres).
-- Moyenne d'une matière = (moyenne des devoirs + composition) / 2, puis
-- moyenne générale pondérée par les coefficients (comme le bulletin).
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
begin
  if my_role() is distinct from 'admin' then
    raise exception 'Non autorisé';
  end if;

  with subj as (
    select g.student_id, g.subject_id, sb.coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then (avg(g.score) filter (where g.kind = 'devoir')
               + avg(g.score) filter (where g.kind = 'composition')) / 2
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, sb.coefficient
  ),
  stu as (
    select student_id,
      sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < 10) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles
                 where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce(
      (select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5
      ) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school
        order by p.paid_at desc limit 6
      ) y), '[]'::jsonb)
  ) into v_result;

  return v_result;
end $$;


-- ================= lakol_migration_4.sql =================
-- =====================================================
-- LAKOL : migration 4
-- Messagerie, annonces de l'école, notifications (email / SMS).
-- Prérequis : migrations 1, 2 et 3 déjà lancées.
-- Supabase > SQL Editor > New query > colle tout > Run
-- =====================================================

-- ---------- 1. TÉLÉPHONE ET PRÉFÉRENCES DE NOTIFICATION ----------
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists notify_email boolean not null default true;
alter table profiles add column if not exists notify_sms boolean not null default false;

create or replace function public.update_my_contact(p_phone text, p_email_on boolean, p_sms_on boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g'), '');
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  if p_sms_on and v_phone is null then
    raise exception 'Ajoute ton numéro de téléphone pour recevoir des SMS';
  end if;
  update profiles set phone = v_phone, notify_email = coalesce(p_email_on, true), notify_sms = coalesce(p_sms_on, false)
  where id = auth.uid();
end $$;

-- ---------- 2. FILE D'ENVOI DES NOTIFICATIONS ----------
create table if not exists notification_queue (
  id uuid primary key default gen_random_uuid(),
  school_id uuid references schools(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  channel text not null check (channel in ('email', 'sms')),
  subject text not null,
  body text not null,
  dedupe_key text not null,
  status text not null default 'pending' check (status in ('pending', 'sending', 'sent', 'failed', 'skipped')),
  error text,
  created_at timestamptz default now(),
  sent_at timestamptz,
  unique (user_id, channel, dedupe_key)
);
create index if not exists notification_queue_pending on notification_queue (status, created_at);
-- Aucune règle d'accès : personne ne la lit depuis le site, seul le serveur d'envoi y accède.
alter table notification_queue enable row level security;

-- Ajoute une notification pour une personne (selon ses préférences)
create or replace function public.enqueue_notification(p_user uuid, p_subject text, p_body text, p_key text)
returns void language plpgsql security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  select * into p from profiles where id = p_user and active;
  if not found then return; end if;
  if p.notify_email and p.email is not null then
    insert into notification_queue (school_id, user_id, channel, subject, body, dedupe_key)
    values (p.school_id, p.id, 'email', p_subject, p_body, p_key) on conflict do nothing;
  end if;
  if p.notify_sms and p.phone is not null then
    insert into notification_queue (school_id, user_id, channel, subject, body, dedupe_key)
    values (p.school_id, p.id, 'sms', p_subject, p_body, p_key) on conflict do nothing;
  end if;
end $$;

-- ---------- 3. ANNONCES DE L'ÉCOLE ----------
create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null default auth.uid(),
  title text not null,
  body text not null,
  audience text not null default 'all' check (audience in ('all', 'parents', 'teachers')),
  kind text not null default 'info' check (kind in ('info', 'urgent', 'closure')),
  pinned boolean not null default false,
  created_at timestamptz default now()
);
create index if not exists announcements_school on announcements (school_id, created_at desc);
alter table announcements enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'announcements'
  loop execute format('drop policy %I on public.announcements', r.policyname); end loop;
end $$;

create policy "announcements_read" on announcements
  for select using (
    school_id = my_school_id() and (
      my_role() = 'admin'
      or audience = 'all'
      or (audience = 'parents' and my_role() = 'parent')
      or (audience = 'teachers' and my_role() = 'teacher')
    )
  );
create policy "announcements_admin" on announcements
  for all using (school_id = my_school_id() and my_role() = 'admin')
  with check (school_id = my_school_id() and my_role() = 'admin');

create or replace function public.trg_announcement_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_prefix text;
begin
  v_prefix := case new.kind when 'urgent' then '🔴 Urgent : ' when 'closure' then '🏫 Pas de cours : ' else '📢 ' end;
  for r in
    select id from profiles
    where school_id = new.school_id and active and id <> coalesce(new.author_id, '00000000-0000-0000-0000-000000000000')
      and (new.audience = 'all'
           or (new.audience = 'parents' and role = 'parent')
           or (new.audience = 'teachers' and role = 'teacher'))
  loop
    perform enqueue_notification(r.id, v_prefix || new.title, left(new.body, 600), 'ann:' || new.id);
  end loop;
  return new;
end $$;
drop trigger if exists announcement_notify on announcements;
create trigger announcement_notify after insert on announcements
  for each row execute function public.trg_announcement_notify();

-- ---------- 4. MESSAGERIE ----------
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references schools(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  student_id uuid references students(id) on delete set null,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz default now(),
  read_at timestamptz
);
create index if not exists messages_recipient on messages (recipient_id, read_at);
create index if not exists messages_pair on messages (sender_id, recipient_id, created_at);
alter table messages enable row level security;

do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'messages'
  loop execute format('drop policy %I on public.messages', r.policyname); end loop;
end $$;

-- On lit seulement ses propres messages ; l'envoi passe par les fonctions ci-dessous.
create policy "messages_mine" on messages
  for select using (sender_id = auth.uid() or recipient_id = auth.uid());

-- Qui peut écrire à qui
create or replace function public.can_message(p_recipient uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare me uuid := auth.uid(); my_r text := my_role(); rec profiles%rowtype;
begin
  if me is null or p_recipient = me then return false; end if;
  select * into rec from profiles where id = p_recipient and active and school_id = my_school_id();
  if not found then return false; end if;
  if my_r = 'admin' then return true; end if;
  if my_r = 'teacher' then
    if rec.role = 'admin' then return true; end if;
    return rec.role = 'parent' and exists (
      select 1 from parents_students ps where ps.parent_id = p_recipient and teaches_student(ps.student_id));
  end if;
  if my_r = 'parent' then
    if rec.role = 'admin' then return true; end if;
    return rec.role = 'teacher' and exists (
      select 1 from parents_students ps join students s on s.id = ps.student_id
      join teaching t on t.class_id = s.class_id
      where ps.parent_id = me and t.teacher_id = p_recipient);
  end if;
  return false;
end $$;

-- Personnes que je peux contacter
create or replace function public.my_contacts()
returns table (id uuid, full_name text, role text, context text)
language plpgsql stable security definer set search_path = public as $$
declare my_r text := my_role();
begin
  if my_r is null then return; end if;
  return query
  select p.id, p.full_name, p.role,
    case p.role
      when 'parent' then (select string_agg(s.first_name || ' ' || s.last_name || coalesce(' (' || c.name || ')', ''), ', ')
                          from parents_students ps join students s on s.id = ps.student_id left join classes c on c.id = s.class_id
                          where ps.parent_id = p.id)
      when 'teacher' then (select string_agg(distinct sb.name, ', ') from teaching t join subjects sb on sb.id = t.subject_id where t.teacher_id = p.id)
      else 'Direction'
    end
  from profiles p
  where p.school_id = my_school_id() and p.active and p.id <> auth.uid() and can_message(p.id)
  order by p.role, p.full_name;
end $$;

create or replace function public.notify_new_message(p_msg uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m messages%rowtype; v_name text;
begin
  select * into m from messages where id = p_msg;
  select full_name into v_name from profiles where id = m.sender_id;
  perform enqueue_notification(m.recipient_id, '💬 Nouveau message de ' || coalesce(v_name, 'l''école'), left(m.body, 400), 'msg:' || m.id);
end $$;

create or replace function public.send_message(p_recipient uuid, p_student uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'Écris ton message'; end if;
  if not can_message(p_recipient) then raise exception 'Tu ne peux pas écrire à cette personne'; end if;
  insert into messages (school_id, sender_id, recipient_id, student_id, body)
  values (my_school_id(), auth.uid(), p_recipient, p_student, trim(p_body)) returning id into v_id;
  perform notify_new_message(v_id);
  return v_id;
end $$;

-- Message groupé : 'parents' | 'teachers' | 'class' (parents d'une classe)
create or replace function public.send_bulk(p_target text, p_class_id uuid, p_body text)
returns int language plpgsql security definer set search_path = public as $$
declare v_role text := my_role(); v_count int := 0; r record; v_id uuid;
begin
  if coalesce(trim(p_body), '') = '' then raise exception 'Écris ton message'; end if;
  if v_role not in ('admin', 'teacher') then raise exception 'Non autorisé'; end if;
  if v_role = 'teacher' and p_target <> 'class' then raise exception 'Un professeur écrit aux parents d''une de ses classes'; end if;
  if p_target = 'class' then
    if p_class_id is null or not class_in_my_school(p_class_id) then raise exception 'Choisis une classe'; end if;
    if v_role = 'teacher' and not teaches_class(p_class_id) then raise exception 'Tu n''enseignes pas dans cette classe'; end if;
  end if;
  for r in
    select distinct p.id from profiles p
    where p.school_id = my_school_id() and p.active and p.id <> auth.uid()
      and ((p_target = 'parents' and p.role = 'parent')
        or (p_target = 'teachers' and p.role = 'teacher')
        or (p_target = 'class' and p.role = 'parent' and exists (
              select 1 from parents_students ps join students s on s.id = ps.student_id
              where ps.parent_id = p.id and s.class_id = p_class_id)))
  loop
    insert into messages (school_id, sender_id, recipient_id, body)
    values (my_school_id(), auth.uid(), r.id, trim(p_body)) returning id into v_id;
    perform notify_new_message(v_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- Mes conversations (une ligne par personne)
create or replace function public.my_conversations()
returns table (other_id uuid, other_name text, other_role text, last_body text, last_at timestamptz, last_from_me boolean, unread int)
language sql stable security definer set search_path = public as $$
  with m as (
    select case when sender_id = auth.uid() then recipient_id else sender_id end as other,
           body, created_at, sender_id = auth.uid() as mine, (recipient_id = auth.uid() and read_at is null) as is_unread
    from messages where sender_id = auth.uid() or recipient_id = auth.uid()
  ),
  last as (select distinct on (other) other, body, created_at, mine from m order by other, created_at desc)
  select l.other, p.full_name, p.role, l.body, l.created_at, l.mine,
         (select count(*) from m where m.other = l.other and m.is_unread)::int
  from last l join profiles p on p.id = l.other
  order by l.created_at desc;
$$;

create or replace function public.unread_messages()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from messages where recipient_id = auth.uid() and read_at is null;
$$;

create or replace function public.mark_thread_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now() where recipient_id = auth.uid() and sender_id = p_other and read_at is null;
$$;

-- ---------- 5. NOTIFICATIONS AUTOMATIQUES AUX PARENTS ----------
-- Nouvelle note
create or replace function public.trg_grade_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_stu students%rowtype; v_label text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  select * into v_stu from students where id = new.student_id;
  v_label := case new.kind when 'composition' then 'composition' else 'devoir' end;
  for r in select parent_id from parents_students where student_id = new.student_id loop
    perform enqueue_notification(r.parent_id,
      '📝 Nouvelle note : ' || coalesce(v_sub, 'matière') || ' (' || v_label || ')',
      v_stu.first_name || ' a une nouvelle note en ' || coalesce(v_sub, 'matière') || ' (trimestre ' || new.term || ') : ' || new.score || '/20.',
      'grade:' || new.student_id || ':' || new.subject_id || ':' || new.term || ':' || new.kind || ':' || current_date);
  end loop;
  return new;
end $$;
drop trigger if exists grade_notify on grades;
create trigger grade_notify after insert on grades for each row execute function public.trg_grade_notify();

-- Nouveau devoir / examen annoncé pour la classe
create or replace function public.trg_assignment_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_kind text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  v_kind := case new.kind when 'examen' then 'Examen' when 'composition' then 'Composition' else 'Devoir' end;
  for r in
    select distinct ps.parent_id from parents_students ps join students s on s.id = ps.student_id where s.class_id = new.class_id
  loop
    perform enqueue_notification(r.parent_id,
      '📅 ' || v_kind || ' prévu : ' || new.title,
      v_kind || coalesce(' en ' || v_sub, '') || ' le ' || to_char(new.due_date, 'DD/MM/YYYY') || '. ' || new.title ||
        coalesce(' (chapitres : ' || new.chapters || ')', ''),
      'asg:' || new.id);
  end loop;
  return new;
end $$;
drop trigger if exists assignment_notify on assignments;
create trigger assignment_notify after insert on assignments for each row execute function public.trg_assignment_notify();

-- ================= lakol_migration_5.sql =================
-- Lakol migration 5 : noms de notes + paramètres de l'école (périodes, barème, poids, note de passage, coefficients par classe)
-- À lancer UNE fois dans Supabase > SQL Editor. Peut être relancée sans danger.

-- ---------- 1. Chaque note a un nom ----------
alter table public.grades add column if not exists title text;
alter table public.grades drop constraint if exists grades_title_len;
alter table public.grades add constraint grades_title_len check (title is null or char_length(title) <= 60);

-- ---------- 2. Paramètres de l'école ----------
alter table public.schools add column if not exists settings jsonb not null default
  '{"period_name":"trimestre","periods":3,"scale":20,"weight_devoir":50,"pass_mark":10,"show_rank":true,"language":"fr","bulletin_header":"République du Niger\nFraternité · Travail · Progrès"}'::jsonb;

-- Périodes jusqu'à 4, barème jusqu'à 100 (les contrôles précis sont faits par update_school_settings)
do $$ declare c record; begin
  for c in select conrelid::regclass as t, conname from pg_constraint
           where contype = 'c' and conrelid in ('public.grades'::regclass, 'public.assignments'::regclass)
             and (pg_get_constraintdef(oid) ilike '%term%' or pg_get_constraintdef(oid) ilike '%score%')
  loop execute format('alter table %s drop constraint %I', c.t, c.conname); end loop;
end $$;
-- Ancienne vue du premier schéma, jamais utilisée par l'application (elle bloquerait le changement de type)
drop view if exists public.student_subject_averages;
alter table public.grades alter column score type numeric(5,2);
alter table public.grades add constraint grades_term_ok check (term between 1 and 4);
alter table public.grades add constraint grades_score_ok check (score >= 0 and score <= 100);
alter table public.assignments add constraint assignments_term_ok check (term is null or term between 1 and 4);

create or replace function public.update_school_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v jsonb; v_clean jsonb;
  v_periods int; v_scale int; v_weight numeric; v_pass numeric; v_name text; v_lang text; v_head text; v_rank boolean;
begin
  if my_role() is distinct from 'admin' then raise exception 'Seul le directeur peut modifier les paramètres.'; end if;
  select settings into v from schools where id = v_school;
  v := coalesce(v, '{}'::jsonb) || coalesce(p_settings, '{}'::jsonb);

  v_name := v->>'period_name'; v_lang := v->>'language'; v_head := coalesce(v->>'bulletin_header', '');
  v_periods := (v->>'periods')::int; v_scale := (v->>'scale')::int;
  v_weight := (v->>'weight_devoir')::numeric; v_pass := (v->>'pass_mark')::numeric; v_rank := coalesce((v->>'show_rank')::boolean, true);

  if v_name not in ('trimestre', 'semestre') then raise exception 'Type de période invalide.'; end if;
  if v_periods < 2 or v_periods > 4 then raise exception 'Le nombre de périodes doit être entre 2 et 4.'; end if;
  if v_scale not in (10, 20, 100) then raise exception 'Le barème doit être /10, /20 ou /100.'; end if;
  if v_weight < 0 or v_weight > 100 then raise exception 'Le poids des devoirs doit être entre 0 et 100 %%.'; end if;
  if v_pass < 0 or v_pass > v_scale then raise exception 'La note de passage doit être entre 0 et %.', v_scale; end if;
  if v_lang not in ('fr', 'en') then raise exception 'Langue invalide.'; end if;
  if char_length(v_head) > 160 then raise exception 'En-tête trop long (160 caractères maximum).'; end if;

  -- Sécurité : on ne casse pas les notes déjà saisies
  if exists (select 1 from grades where school_id = v_school and term > v_periods) then
    raise exception 'Des notes existent déjà après la période % : impossible de réduire le nombre de périodes.', v_periods;
  end if;
  if exists (select 1 from grades where school_id = v_school and score > v_scale) then
    raise exception 'Des notes existent déjà au-dessus de % : impossible de réduire le barème. Les notes ne sont pas converties automatiquement.', v_scale;
  end if;

  v_clean := jsonb_build_object('period_name', v_name, 'periods', v_periods, 'scale', v_scale, 'weight_devoir', v_weight,
    'pass_mark', v_pass, 'show_rank', v_rank, 'language', v_lang, 'bulletin_header', v_head);
  update schools set settings = v_clean where id = v_school;
  return v_clean;
end $$;

-- ---------- 3. Coefficients par classe (6e et terminale n'ont pas les mêmes) ----------
create table if not exists public.class_coefficients (
  class_id uuid not null references classes(id) on delete cascade,
  subject_id uuid not null references subjects(id) on delete cascade,
  coefficient numeric(4,2) not null check (coefficient > 0 and coefficient <= 20),
  primary key (class_id, subject_id)
);
alter table public.class_coefficients enable row level security;
drop policy if exists cc_select on public.class_coefficients;
drop policy if exists cc_write on public.class_coefficients;
create policy cc_select on public.class_coefficients for select using (class_in_my_school(class_id));
create policy cc_write on public.class_coefficients for all
  using (class_in_my_school(class_id) and (my_role() = 'admin' or teaches_class(class_id)))
  with check (class_in_my_school(class_id) and (my_role() = 'admin' or teaches_class(class_id)));

-- ---------- 4. Email aux parents : nom de la note, période et barème de l'école ----------
create or replace function public.trg_grade_notify()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record; v_sub text; v_stu students%rowtype; v_label text; v_set jsonb; v_pn text; v_scale text;
begin
  select name into v_sub from subjects where id = new.subject_id;
  select * into v_stu from students where id = new.student_id;
  select settings into v_set from schools where id = new.school_id;
  v_pn := coalesce(v_set->>'period_name', 'trimestre'); v_scale := coalesce(v_set->>'scale', '20');
  v_label := coalesce(nullif(trim(new.title), ''), case new.kind when 'composition' then 'Composition' else 'Devoir' end);
  for r in select parent_id from parents_students where student_id = new.student_id loop
    perform enqueue_notification(r.parent_id,
      '📝 Nouvelle note : ' || coalesce(v_sub, 'matière') || ' (' || v_label || ')',
      v_stu.first_name || ' a une nouvelle note en ' || coalesce(v_sub, 'matière') || ' (' || v_label || ', ' || v_pn || ' ' || new.term || ') : ' || trim(trailing '.' from trim(trailing '0' from new.score::text)) || '/' || v_scale || '.',
      'grade:' || new.id);
  end loop;
  return new;
end $$;

-- ---------- 5. Tableau de bord : lit les paramètres de l'école ----------
create or replace function public.dashboard_overview(p_term int default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_school uuid := my_school_id();
  v_result jsonb;
  v_set jsonb;
  v_wd numeric; v_pass numeric;
begin
  if my_role() is distinct from 'admin' then raise exception 'Non autorisé'; end if;
  select settings into v_set from schools where id = v_school;
  v_wd := coalesce((v_set->>'weight_devoir')::numeric, 50) / 100;
  v_pass := coalesce((v_set->>'pass_mark')::numeric, 10);

  with subj as (
    select g.student_id, g.subject_id, coalesce(cc.coefficient, sb.coefficient) as coefficient,
      case when count(*) filter (where g.kind = 'devoir') > 0
            and count(*) filter (where g.kind = 'composition') > 0
           then v_wd * (avg(g.score) filter (where g.kind = 'devoir'))
              + (1 - v_wd) * (avg(g.score) filter (where g.kind = 'composition'))
           else avg(g.score) end as avg_subject
    from grades g
    join subjects sb on sb.id = g.subject_id
    join students st on st.id = g.student_id
    left join class_coefficients cc on cc.class_id = st.class_id and cc.subject_id = g.subject_id
    where g.school_id = v_school and (p_term is null or g.term = p_term)
    group by g.student_id, g.subject_id, coalesce(cc.coefficient, sb.coefficient)
  ),
  stu as (
    select student_id, sum(avg_subject * coefficient) / nullif(sum(coefficient), 0) as gen_avg
    from subj group by student_id
  ),
  cls as (
    select c.id, c.name, c.school_year,
      count(distinct s.id) as students,
      round(avg(stu.gen_avg)::numeric, 2) as average,
      count(stu.gen_avg) filter (where stu.gen_avg < v_pass) as struggling
    from classes c
    left join students s on s.class_id = c.id
    left join stu on stu.student_id = s.id
    where c.school_id = v_school
    group by c.id, c.name, c.school_year
  ),
  bal as (
    select s.id, s.first_name, s.last_name, c.name as class_name,
      coalesce((select sum(f.amount) from fees f where f.class_id = s.class_id or (f.class_id is null and f.school_id = s.school_id)), 0) as due,
      coalesce((select sum(p.amount) from payments p where p.student_id = s.id), 0) as paid
    from students s
    left join classes c on c.id = s.class_id
    where s.school_id = v_school
  )
  select jsonb_build_object(
    'students', (select count(*) from students where school_id = v_school),
    'classes', (select count(*) from classes where school_id = v_school),
    'teachers', (select count(*) from profiles where school_id = v_school and role = 'teacher' and active),
    'total_due', (select coalesce(sum(due), 0) from bal),
    'total_paid', (select coalesce(sum(paid), 0) from bal),
    'class_stats', coalesce((select jsonb_agg(to_jsonb(cls) order by cls.name) from cls), '[]'::jsonb),
    'top_unpaid', coalesce((
      select jsonb_agg(to_jsonb(x)) from (
        select id, first_name, last_name, class_name, due, paid, due - paid as remaining
        from bal where due > paid order by due - paid desc limit 5) x), '[]'::jsonb),
    'recent_payments', coalesce((
      select jsonb_agg(to_jsonb(y)) from (
        select p.id, p.amount, p.method, p.paid_at, s.first_name, s.last_name
        from payments p join students s on s.id = p.student_id
        where p.school_id = v_school order by p.paid_at desc limit 6) y), '[]'::jsonb)
  ) into v_result;
  return v_result;
end $$;

-- ================= lakol_migration_6.sql =================
-- Lakol migration 6 : sécurité
--   A. Double authentification (MFA) appliquée par la base de données
--   B. Journal d'audit (qui a changé quoi, et quand)
-- À lancer UNE fois dans Supabase > SQL Editor. Peut être relancée sans danger.

-- =====================================================================
-- A. DOUBLE AUTHENTIFICATION
-- Règle : si un compte a activé la double authentification, il n'a accès à rien tant que
-- la session n'a pas été confirmée avec le code à 6 chiffres (niveau "aal2").
-- Un compte sans double authentification fonctionne comme avant.
-- =====================================================================
create or replace function public.mfa_ok()
returns boolean language sql stable security definer set search_path = public, auth as $$
  select coalesce(nullif(auth.jwt() ->> 'aal', ''), 'aal1') = 'aal2'
      or not exists (select 1 from auth.mfa_factors where user_id = auth.uid() and status::text = 'verified')
$$;

-- Presque toutes les règles d'accès passent par ces deux fonctions : sans code, elles ne répondent plus.
create or replace function public.my_school_id()
returns uuid language sql stable security definer set search_path = public as $$
  select school_id from profiles where id = auth.uid() and active and mfa_ok()
$$;
create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active and mfa_ok()
$$;

-- Tables qui s'appuient directement sur l'identité (sans passer par les fonctions ci-dessus)
drop policy if exists mfa_guard on public.messages;
create policy mfa_guard on public.messages as restrictive for all using (mfa_ok()) with check (mfa_ok());
drop policy if exists mfa_guard on public.parents_students;
create policy mfa_guard on public.parents_students as restrictive for all using (mfa_ok()) with check (mfa_ok());

-- Fonctions de messagerie : même verrou
create or replace function public.unread_messages()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from messages where recipient_id = auth.uid() and read_at is null and mfa_ok()
$$;
create or replace function public.mark_thread_read(p_other uuid)
returns void language sql security definer set search_path = public as $$
  update messages set read_at = now() where recipient_id = auth.uid() and sender_id = p_other and read_at is null and mfa_ok();
$$;

create or replace function public.my_conversations()
returns table (other_id uuid, other_name text, other_role text, last_body text, last_at timestamptz, last_from_me boolean, unread int)
language sql stable security definer set search_path = public as $$
  with m as (
    select case when sender_id = auth.uid() then recipient_id else sender_id end as other,
           body, created_at, sender_id = auth.uid() as mine, (recipient_id = auth.uid() and read_at is null) as is_unread
    from messages where (sender_id = auth.uid() or recipient_id = auth.uid()) and mfa_ok()
  ),
  last as (select distinct on (other) other, body, created_at, mine from m order by other, created_at desc)
  select l.other, p.full_name, p.role, l.body, l.created_at, l.mine,
         (select count(*) from m where m.other = l.other and m.is_unread)::int
  from last l join profiles p on p.id = l.other
  order by l.created_at desc;
$$;

-- =====================================================================
-- B. JOURNAL D'AUDIT
-- =====================================================================
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  school_id uuid not null references schools(id) on delete cascade,
  actor_id uuid,
  actor_name text,
  actor_role text,
  action text not null check (action in ('create', 'update', 'delete')),
  entity text not null,           -- note, paiement, frais, eleve, compte, salaire, classe, parametres
  record_id text,
  summary text not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_school_date on public.audit_log (school_id, created_at desc);
create index if not exists audit_school_entity on public.audit_log (school_id, entity, created_at desc);
alter table public.audit_log enable row level security;
drop policy if exists audit_admin_read on public.audit_log;
create policy audit_admin_read on public.audit_log for select using (school_id = my_school_id() and my_role() = 'admin');
-- Aucune règle d'écriture : personne ne peut ajouter, modifier ou effacer une ligne depuis l'application.
-- Seuls les déclencheurs ci-dessous écrivent.

create or replace function public.audit_money(n numeric)
returns text language sql immutable as $$ select replace(to_char(n, 'FM999,999,999,999'), ',', ' ') || ' F' $$;
create or replace function public.audit_num(n numeric)
returns text language sql immutable as $$ select trim(trailing '.' from trim(trailing '0' from n::numeric(8,2)::text)) $$;

create or replace function public.trg_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb; v_new jsonb; v_row jsonb;
  v_school uuid; v_entity text; v_sum text; v_act text; v_rid text;
  v_actor uuid := auth.uid(); v_name text; v_role text;
  v_stu text; v_sub text; v_lbl text; v_cls text; v_tch text; v_m text;
begin
  v_old := case when TG_OP in ('UPDATE', 'DELETE') then to_jsonb(OLD) end;
  v_new := case when TG_OP in ('INSERT', 'UPDATE') then to_jsonb(NEW) end;
  v_row := coalesce(v_new, v_old);
  v_act := case TG_OP when 'INSERT' then 'create' when 'UPDATE' then 'update' else 'delete' end;
  v_rid := v_row ->> 'id';
  if v_actor is not null then select full_name, role into v_name, v_role from profiles where id = v_actor; end if;

  if TG_TABLE_NAME = 'grades' then
    v_entity := 'note'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from students where id = (v_row ->> 'student_id')::uuid) then return OLD; end if;
    if TG_OP = 'UPDATE' and v_old ->> 'score' = v_new ->> 'score' and coalesce(v_old ->> 'title', '') = coalesce(v_new ->> 'title', '')
       and v_old ->> 'term' = v_new ->> 'term' and v_old ->> 'kind' = v_new ->> 'kind' then return NEW; end if;
    select first_name || ' ' || last_name into v_stu from students where id = (v_row ->> 'student_id')::uuid;
    select name into v_sub from subjects where id = (v_row ->> 'subject_id')::uuid;
    v_lbl := coalesce(nullif(v_row ->> 'title', ''), case v_row ->> 'kind' when 'composition' then 'Composition' else 'Devoir' end);
    if TG_OP = 'INSERT' then v_sum := format('Note ajoutée : %s, %s (%s) = %s', v_stu, v_sub, v_lbl, audit_num((v_new ->> 'score')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Note modifiée : %s, %s (%s) : %s → %s', v_stu, v_sub, v_lbl, audit_num((v_old ->> 'score')::numeric), audit_num((v_new ->> 'score')::numeric));
    else v_sum := format('Note supprimée : %s, %s (%s), elle valait %s', v_stu, v_sub, v_lbl, audit_num((v_old ->> 'score')::numeric)); end if;

  elsif TG_TABLE_NAME = 'payments' then
    v_entity := 'paiement'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from students where id = (v_row ->> 'student_id')::uuid) then return OLD; end if;
    select first_name || ' ' || last_name into v_stu from students where id = (v_row ->> 'student_id')::uuid;
    if TG_OP = 'INSERT' then v_sum := format('Paiement enregistré : %s pour %s (%s)', audit_money((v_new ->> 'amount')::numeric), v_stu, v_new ->> 'method');
    elsif TG_OP = 'UPDATE' then v_sum := format('Paiement modifié pour %s : %s → %s', v_stu, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Paiement supprimé pour %s : %s', v_stu, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'fees' then
    v_entity := 'frais'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    select name into v_cls from classes where id = (v_row ->> 'class_id')::uuid;
    v_lbl := format('« %s » (%s)', v_row ->> 'label', coalesce(v_cls, 'toute l''école'));
    if TG_OP = 'INSERT' then v_sum := format('Frais créés : %s = %s', v_lbl, audit_money((v_new ->> 'amount')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Frais modifiés : %s : %s → %s', v_lbl, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Frais supprimés : %s (%s)', v_lbl, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'students' then
    v_entity := 'eleve'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'INSERT' then return NEW; end if;  -- les ajouts en série ne sont pas journalisés
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    v_stu := (v_row ->> 'first_name') || ' ' || (v_row ->> 'last_name');
    if TG_OP = 'UPDATE' then
      if v_old ->> 'class_id' is not distinct from v_new ->> 'class_id' and v_old ->> 'first_name' = v_new ->> 'first_name' and v_old ->> 'last_name' = v_new ->> 'last_name' then return NEW; end if;
      select name into v_cls from classes where id = (v_old ->> 'class_id')::uuid;
      select name into v_lbl from classes where id = (v_new ->> 'class_id')::uuid;
      v_sum := format('Élève modifié : %s (classe %s → %s)', v_stu, coalesce(v_cls, '–'), coalesce(v_lbl, '–'));
    else v_sum := format('Élève supprimé : %s', v_stu); end if;
    v_old := case when v_old is null then null else jsonb_build_object('first_name', v_old -> 'first_name', 'last_name', v_old -> 'last_name', 'class_id', v_old -> 'class_id') end;
    v_new := case when v_new is null then null else jsonb_build_object('first_name', v_new -> 'first_name', 'last_name', v_new -> 'last_name', 'class_id', v_new -> 'class_id') end;

  elsif TG_TABLE_NAME = 'classes' then
    v_entity := 'classe'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'INSERT' then return NEW; end if;
    if TG_OP = 'DELETE' and not exists (select 1 from schools where id = v_school) then return OLD; end if;
    if TG_OP = 'UPDATE' then
      if v_old ->> 'name' = v_new ->> 'name' and v_old ->> 'school_year' = v_new ->> 'school_year' then return NEW; end if;
      v_sum := format('Classe renommée : %s → %s', v_old ->> 'name', v_new ->> 'name');
    else v_sum := format('Classe supprimée : %s', v_old ->> 'name'); end if;
    v_old := case when v_old is null then null else jsonb_build_object('name', v_old -> 'name', 'school_year', v_old -> 'school_year') end;
    v_new := case when v_new is null then null else jsonb_build_object('name', v_new -> 'name', 'school_year', v_new -> 'school_year') end;

  elsif TG_TABLE_NAME = 'staff_pay' then
    v_entity := 'salaire'; v_school := (v_row ->> 'school_id')::uuid; v_rid := v_row ->> 'teacher_id';
    select full_name into v_tch from profiles where id = (v_row ->> 'teacher_id')::uuid;
    if TG_OP = 'INSERT' then v_sum := format('Salaire mensuel fixé pour %s : %s', v_tch, audit_money((v_new ->> 'monthly_salary')::numeric));
    elsif TG_OP = 'UPDATE' then
      if v_old ->> 'monthly_salary' = v_new ->> 'monthly_salary' then return NEW; end if;
      v_sum := format('Salaire mensuel de %s : %s → %s', v_tch, audit_money((v_old ->> 'monthly_salary')::numeric), audit_money((v_new ->> 'monthly_salary')::numeric));
    else
      if not exists (select 1 from profiles where id = (v_row ->> 'teacher_id')::uuid) then return OLD; end if;
      v_sum := format('Salaire mensuel supprimé pour %s', v_tch); end if;

  elsif TG_TABLE_NAME = 'salary_payments' then
    v_entity := 'salaire'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP = 'DELETE' and not exists (select 1 from profiles where id = (v_row ->> 'teacher_id')::uuid) then return OLD; end if;
    select full_name into v_tch from profiles where id = (v_row ->> 'teacher_id')::uuid;
    v_m := v_row ->> 'month';
    if TG_OP = 'INSERT' then v_sum := format('Salaire versé à %s (%s) : %s', v_tch, v_m, audit_money((v_new ->> 'amount')::numeric));
    elsif TG_OP = 'UPDATE' then v_sum := format('Versement de salaire modifié pour %s (%s) : %s → %s', v_tch, v_m, audit_money((v_old ->> 'amount')::numeric), audit_money((v_new ->> 'amount')::numeric));
    else v_sum := format('Versement de salaire supprimé pour %s (%s) : %s', v_tch, v_m, audit_money((v_old ->> 'amount')::numeric)); end if;

  elsif TG_TABLE_NAME = 'profiles' then
    v_entity := 'compte'; v_school := (v_row ->> 'school_id')::uuid;
    if v_school is null then return coalesce(NEW, OLD); end if;
    if TG_OP = 'INSERT' then return NEW; end if;
    if TG_OP = 'UPDATE' then
      if v_old ->> 'active' = v_new ->> 'active' and v_old ->> 'role' = v_new ->> 'role' then return NEW; end if;
      if v_old ->> 'active' <> v_new ->> 'active' then
        v_sum := format('Compte %s : %s', case when (v_new ->> 'active')::boolean then 'réactivé' else 'désactivé' end, v_new ->> 'full_name');
      else v_sum := format('Rôle modifié pour %s : %s → %s', v_new ->> 'full_name', v_old ->> 'role', v_new ->> 'role'); end if;
    else
      if not exists (select 1 from schools where id = v_school) then return OLD; end if;
      v_sum := format('Compte supprimé : %s', v_old ->> 'full_name'); end if;
    v_old := case when v_old is null then null else jsonb_build_object('full_name', v_old -> 'full_name', 'role', v_old -> 'role', 'active', v_old -> 'active') end;
    v_new := case when v_new is null then null else jsonb_build_object('full_name', v_new -> 'full_name', 'role', v_new -> 'role', 'active', v_new -> 'active') end;

  elsif TG_TABLE_NAME = 'schools' then
    v_entity := 'parametres'; v_school := (v_row ->> 'id')::uuid;
    if TG_OP <> 'UPDATE' then return coalesce(NEW, OLD); end if;
    if v_old -> 'settings' is not distinct from v_new -> 'settings' and v_old ->> 'name' = v_new ->> 'name' then return NEW; end if;
    v_sum := case when v_old -> 'settings' is distinct from v_new -> 'settings' then 'Paramètres de l''école modifiés' else format('Nom de l''école : %s → %s', v_old ->> 'name', v_new ->> 'name') end;
    v_old := jsonb_build_object('name', v_old -> 'name', 'settings', v_old -> 'settings');
    v_new := jsonb_build_object('name', v_new -> 'name', 'settings', v_new -> 'settings');

  elsif TG_TABLE_NAME = 'school_secrets' then
    v_entity := 'parametres'; v_school := (v_row ->> 'school_id')::uuid;
    if TG_OP <> 'UPDATE' or v_old ->> 'join_code' = v_new ->> 'join_code' then return coalesce(NEW, OLD); end if;
    v_sum := 'Code de l''école régénéré (les anciens codes ne marchent plus)';
    v_old := null; v_new := null;  -- le code est secret : jamais écrit dans le journal
  else
    return coalesce(NEW, OLD);
  end if;

  insert into audit_log (school_id, actor_id, actor_name, actor_role, action, entity, record_id, summary, old_data, new_data)
  values (v_school, v_actor, coalesce(v_name, 'Système'), v_role, v_act, v_entity, v_rid, v_sum, v_old, v_new);
  return coalesce(NEW, OLD);
end $$;

do $$ declare t text; begin
  foreach t in array array['grades', 'payments', 'fees', 'students', 'classes', 'staff_pay', 'salary_payments', 'profiles', 'schools', 'school_secrets'] loop
    execute format('drop trigger if exists audit_%1$s on public.%1$s', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$s for each row execute function public.trg_audit()', t);
  end loop;
end $$;
