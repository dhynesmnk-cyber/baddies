-- Becoming Baddies - the two logins
--
-- There is no sign up in the app. Dave and Angus are fixed, and both unlock
-- with the same 4 digit PIN. This script creates the two Supabase auth users
-- and links a profile row to each. It is safe to run repeatedly, and re-running
-- it resets both passwords, which is how you change the PIN.
--
-- ---------------------------------------------------------------------
-- About the PIN
-- ---------------------------------------------------------------------
--
-- Supabase enforces a minimum password length of 6, so "9876" cannot be the
-- password itself. The app turns the PIN you type into the real password by
-- appending a fixed suffix:
--
--     password = <pin> || '-becoming-baddies'
--
-- So the stored password below is '9876-becoming-baddies'. Only the recipe is
-- in the published HTML, never the PIN, so someone reading the page source
-- still has to know the four digits.
--
-- To change the PIN: edit new_pin below, run this file again, and change
-- nothing in the app.
--
-- ---------------------------------------------------------------------
-- If this script errors
-- ---------------------------------------------------------------------
--
-- It writes to auth.users and auth.identities, whose exact columns vary
-- between Supabase versions. If it fails, create the two users by hand in the
-- dashboard instead - Authentication, Users, Add user, with Auto Confirm User
-- ticked - using these emails and the password '9876-becoming-baddies', then
-- run just the final insert at the bottom of this file to link the profiles.

create extension if not exists pgcrypto;

do $$
declare
  new_pin text := '9876';
  new_password text;
  target record;
  user_id uuid;
begin
  new_password := new_pin || '-becoming-baddies';

  for target in
    select *
    from (values
      ('dave@becomingbaddies.local', 'Dave'),
      ('angus@becomingbaddies.local', 'Angus')
    ) as t(email, display_name)
  loop
    select id into user_id from auth.users where email = target.email;

    if user_id is null then
      user_id := gen_random_uuid();

      insert into auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data
      )
      values (
        '00000000-0000-0000-0000-000000000000',
        user_id,
        'authenticated',
        'authenticated',
        target.email,
        crypt(new_password, gen_salt('bf')),
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{}'::jsonb
      );

      insert into auth.identities (
        provider_id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at
      )
      values (
        user_id::text,
        user_id,
        jsonb_build_object(
          'sub', user_id::text,
          'email', target.email,
          'email_verified', true
        ),
        'email',
        now(),
        now(),
        now()
      );
    else
      -- Already exists, so just resync the password to the current PIN.
      update auth.users
      set encrypted_password = crypt(new_password, gen_salt('bf')),
          updated_at = now()
      where id = user_id;
    end if;

    insert into public.profiles (owner_id, name)
    values (user_id, target.display_name)
    on conflict (name) do update
      set owner_id = excluded.owner_id;
  end loop;
end
$$;

-- Link profiles only. Use this on its own if you created the two users by hand
-- in the dashboard.
insert into public.profiles (owner_id, name)
select id, 'Dave' from auth.users where email = 'dave@becomingbaddies.local'
on conflict (name) do update set owner_id = excluded.owner_id;

insert into public.profiles (owner_id, name)
select id, 'Angus' from auth.users where email = 'angus@becomingbaddies.local'
on conflict (name) do update set owner_id = excluded.owner_id;
