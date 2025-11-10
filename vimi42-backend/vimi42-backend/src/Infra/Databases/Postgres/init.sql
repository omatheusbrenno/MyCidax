-- ========================================
-- 1. Criação dos tipos enumerados
-- ========================================
CREATE TYPE user_type_enum AS ENUM ('prestador', 'cliente');

-- Status precisam ser ajustados conforme definição e enums no Código

CREATE TYPE request_status_enum AS ENUM (
  'aguardando confirmação',
  'aceito',
  'em andamento',
  'concluído',
  'cancelado'
);

-- ========================================
-- 2. Esquema (namespace) opcional
-- ========================================
CREATE SCHEMA IF NOT EXISTS vimi42;
SET search_path = vimi42, public;

-- ========================================
-- 3. Tabelas
-- Observações de design:
-- - usei timestamptz para created_at
-- - ids como GENERATED ALWAYS AS IDENTITY
-- - password_hash para reforçar que armazenamos hash
-- - restrições de unicidade e índices conforme necessidade
-- ========================================

-- USERS
CREATE TABLE vimi42.users (
  id_user          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email            TEXT NOT NULL UNIQUE,
  password_hash    TEXT NOT NULL,
  user_type        user_type_enum NOT NULL,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  full_name        TEXT NOT NULL,
  cpf              TEXT UNIQUE,
  phone_number     TEXT NOT NULL UNIQUE,
  city             TEXT NOT NULL,
  federative_unit  TEXT NOT NULL,
  date_is_born     DATE NOT NULL,
  cnpj             TEXT UNIQUE
);

-- PROVIDER_PROFILE
-- Cada usuário pode ter *no máximo* um profile provider (user_id unique).
CREATE TABLE vimi42.provider_profile (
  provider_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id          INTEGER NOT NULL UNIQUE REFERENCES vimi42.users(id_user) ON DELETE CASCADE,
  bio              TEXT,
  location         TEXT,
  average_rating   NUMERIC(3,2) NOT NULL DEFAULT 0.00, -- ex: 4.25
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- SERVICES
-- Decisão: permiti múltiplos serviços por provider (removi unique em provider_id),
-- pois na maioria dos MVPs um provedor oferece vários serviços.
CREATE TABLE vimi42.services (
  service_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  provider_id      INTEGER NOT NULL REFERENCES vimi42.provider_profile(provider_id) ON DELETE CASCADE,
  categoria        TEXT,
  title            TEXT NOT NULL,
  description      TEXT NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  image            TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

-- SERVICE_REQUEST (agendamentos)
CREATE TABLE vimi42.service_request (
  request_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  provider_id      INTEGER NOT NULL REFERENCES vimi42.provider_profile(provider_id) ON DELETE CASCADE,
  user_id          INTEGER NOT NULL REFERENCES vimi42.users(id_user) ON DELETE CASCADE,
  service_id       INTEGER NOT NULL REFERENCES vimi42.services(service_id) ON DELETE RESTRICT,
  status           request_status_enum NOT NULL DEFAULT 'aguardando confirmação',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  schedule_at      TIMESTAMPTZ NOT NULL
);

-- REVIEWS
-- Um review está ligado a um agendamento (request_id) — ajuda a garantir que só usuários que fizeram o serviço avaliam.
CREATE TABLE vimi42.reviews (
  review_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id       INTEGER NOT NULL REFERENCES vimi42.service_request(request_id) ON DELETE CASCADE,
  rating           INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment          TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 4. Índices adicionais (performance)
-- ========================================
-- Indexes for frequent lookups / filters
CREATE INDEX idx_users_user_type ON vimi42.users(user_type);
CREATE INDEX idx_services_provider_id ON vimi42.services(provider_id);
CREATE INDEX idx_services_created_at ON vimi42.services(created_at);
CREATE INDEX idx_service_request_provider ON vimi42.service_request(provider_id);
CREATE INDEX idx_service_request_user ON vimi42.service_request(user_id);
CREATE INDEX idx_service_request_service ON vimi42.service_request(service_id);
CREATE INDEX idx_service_request_status ON vimi42.service_request(status);
CREATE INDEX idx_reviews_request_id ON vimi42.reviews(request_id);
CREATE INDEX idx_provider_profile_user_id ON vimi42.provider_profile(user_id);

-- ========================================
-- 5. Funções / triggers
-- Recalcula average_rating na provider_profile quando reviews são inseridas/atualizadas/deletadas.
-- ========================================

-- Função que recalcula média com base nas reviews ligadas à requests daquele provider
CREATE OR REPLACE FUNCTION vimi42.recalculate_provider_average()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_provider_id INTEGER;
  v_avg NUMERIC(3,2);
BEGIN
  -- Find provider for the affected request
  SELECT sr.provider_id INTO v_provider_id
  FROM vimi42.service_request sr
  WHERE sr.request_id = NEW.request_id
  LIMIT 1;

  IF v_provider_id IS NULL THEN
    -- try with OLD in case of delete
    SELECT sr.provider_id INTO v_provider_id
    FROM vimi42.service_request sr
    WHERE sr.request_id = OLD.request_id
    LIMIT 1;
    IF v_provider_id IS NULL THEN
      RETURN NULL;
    END IF;
  END IF;

  SELECT ROUND(AVG(r.rating)::numeric, 2) INTO v_avg
  FROM vimi42.reviews r
  JOIN vimi42.service_request sr2 ON sr2.request_id = r.request_id
  WHERE sr2.provider_id = v_provider_id AND r.rating IS NOT NULL;

  IF v_avg IS NULL THEN
    v_avg := 0.00;
  END IF;

  UPDATE vimi42.provider_profile
  SET average_rating = v_avg
  WHERE provider_id = v_provider_id;

  RETURN NULL;
END;
$$;

-- Triggers on reviews: AFTER INSERT, UPDATE, DELETE
CREATE TRIGGER trg_reviews_after_insert
AFTER INSERT ON vimi42.reviews
FOR EACH ROW
EXECUTE PROCEDURE vimi42.recalculate_provider_average();

CREATE TRIGGER trg_reviews_after_update
AFTER UPDATE OF rating ON vimi42.reviews
FOR EACH ROW
EXECUTE PROCEDURE vimi42.recalculate_provider_average();

CREATE TRIGGER trg_reviews_after_delete
AFTER DELETE ON vimi42.reviews
FOR EACH ROW
EXECUTE PROCEDURE vimi42.recalculate_provider_average();

-- ========================================
-- 6. Seed inicial (dados de exemplo)
-- ========================================
SET search_path = vimi42, public;

-- =======================
-- 6.1. USERS
-- =======================
INSERT INTO vimi42.users 
(email, password_hash, user_type, full_name, cpf, cnpj, phone_number, city, federative_unit, date_is_born)
VALUES
-- Prestadores
('joao.araujo@techfix.com', 'HASH_JOAO', 'prestador', 'João Araújo', '12345678901', '11222333000188', '61991234567', 'Brasília', 'DF', '1988-04-21'),
('maria.lima@beautyup.com', 'HASH_MARIA', 'prestador', 'Maria Lima', '23456789012', '22333444000177', '61992345678', 'Goiânia', 'GO', '1992-08-14'),
('carlos.mendes@cleanexpress.com', 'HASH_CARLOS', 'prestador', 'Carlos Mendes', '34567890123', '33444555000166', '61993456789', 'Taguatinga', 'DF', '1985-02-03'),
('fernanda.souza@homecare.com', 'HASH_FERNANDA', 'prestador', 'Fernanda Souza', '45678901234', '44555666000155', '61994567890', 'Águas Claras', 'DF', '1994-09-27'),
('rafael.santos@greenworks.com', 'HASH_RAFAEL', 'prestador', 'Rafael Santos', '56789012345', '55666777000144', '61995678901', 'Valparaíso', 'GO', '1990-12-10'),
('thiago.costa@hidrotech.com', 'HASH_THIAGO', 'prestador', 'Thiago Costa', '11122233344', '66777888000133', '61990234567', 'Brasília', 'DF', '1989-10-01'),
('patricia.gomes@petlove.com', 'HASH_PATRICIA', 'prestador', 'Patrícia Gomes', '22233344455', '77888999000122', '61991345678', 'Luziânia', 'GO', '1991-12-09'),
('anderson.lopes@movefast.com', 'HASH_ANDERSON', 'prestador', 'Anderson Lopes', '33344455566', '88999000111211', '61992456789', 'Taguatinga', 'DF', '1987-05-17'),
('larissa.oliveira@decorart.com', 'HASH_LARISSA', 'prestador', 'Larissa Oliveira', '44455566677', '99000111222300', '61993567890', 'Águas Claras', 'DF', '1993-09-04'),
('renato.silva@techhelp.com', 'HASH_RENATO', 'prestador', 'Renato Silva', '55566677788', '10111222333400', '61994678901', 'Formosa', 'GO', '1985-01-29'),
('camila.dias@fixit.com', 'HASH_CAMILA', 'prestador', 'Camila Dias', '66677788800', '11122333000111', '61991230001', 'Brasília', 'DF', '1991-03-11'),
('eduardo.pinto@eletrik.com', 'HASH_EDUARDO', 'prestador', 'Eduardo Pinto', '77788899911', '22233444000122', '61992340002', 'Goiânia', 'GO', '1987-07-28'),
('aline.martins@cleanhome.com', 'HASH_ALINE', 'prestador', 'Aline Martins', '88899900022', '33344555000133', '61993450003', 'Águas Claras', 'DF', '1995-05-10'),
('paulo.teixeira@fixhouse.com', 'HASH_PAULO', 'prestador', 'Paulo Teixeira', '99900011133', '44455666000144', '61994560004', 'Taguatinga', 'DF', '1984-09-13'),
('leticia.barros@petclean.com', 'HASH_LETICIA', 'prestador', 'Letícia Barros', '00011122244', '55566777000155', '61995670005', 'Valparaíso', 'GO', '1992-10-02'),
('ricardo.alves@greenhouse.com', 'HASH_RICARDO', 'prestador', 'Ricardo Alves', '11122233355', '66677888000166', '61996780006', 'Gama', 'DF', '1988-01-25'),
('simone.freitas@decorhome.com', 'HASH_SIMONE', 'prestador', 'Simone Freitas', '22233344466', '77788999000177', '61997890007', 'Luziânia', 'GO', '1993-04-07'),
('bruno.carvalho@moveit.com', 'HASH_BRUNO', 'prestador', 'Bruno Carvalho', '33344455577', '88899000111288', '61998900008', 'Ceilândia', 'DF', '1986-06-30'),
('tatiane.moraes@beautyhome.com', 'HASH_TATIANE', 'prestador', 'Tatiane Moraes', '44455566688', '99900111222399', '61999010009', 'Águas Claras', 'DF', '1994-11-20'),
('gustavo.ramos@techpro.com', 'HASH_GUSTAVO_R', 'prestador', 'Gustavo Ramos', '55566677799', '10111222333411', '61990120010', 'Formosa', 'GO', '1989-12-18'),
('luana.castro@hidrosafe.com', 'HASH_LUANA', 'prestador', 'Luana Castro', '66677788810', '12122333444522', '61991230011', 'Brasília', 'DF', '1991-09-02'),
('felipe.melo@eletriccity.com', 'HASH_FELIPE_M', 'prestador', 'Felipe Melo', '77788899921', '13133444555633', '61992340012', 'Goiânia', 'GO', '1990-06-21'),
('sabrina.santos@fixhouse.com', 'HASH_SABRINA', 'prestador', 'Sabrina Santos', '88899900032', '14144555666744', '61993450013', 'Taguatinga', 'DF', '1995-02-14'),
('rodrigo.lima@greenfix.com', 'HASH_RODRIGO_L', 'prestador', 'Rodrigo Lima', '99900011143', '15155666777855', '61994560014', 'Valparaíso', 'GO', '1987-11-26'),
('nathalia.azevedo@petshopcare.com', 'HASH_NATHALIA', 'prestador', 'Nathalia Azevedo', '00011122254', '16166777888966', '61995670015', 'Gama', 'DF', '1993-08-19'),
('tiago.martins@cleansafe.com', 'HASH_TIAGO_M', 'prestador', 'Tiago Martins', '11122233365', '17177888999077', '61996780016', 'Luziânia', 'GO', '1985-04-30'),
('aline.ferreira@movehome.com', 'HASH_ALINE_F', 'prestador', 'Aline Ferreira', '22233344476', '18188999000188', '61997890017', 'Ceilândia', 'DF', '1994-05-12'),
('caio.souza@techplus.com', 'HASH_CAIO', 'prestador', 'Caio Souza', '33344455587', '19199000111299', '61998900018', 'Brasília', 'DF', '1988-10-06'),
('renata.mendes@decorfix.com', 'HASH_RENATA', 'prestador', 'Renata Mendes', '44455566698', '20200111222300', '61999010019', 'Águas Claras', 'DF', '1992-01-30'),
('marcos.vieira@hydrocare.com', 'HASH_MARCOS', 'prestador', 'Marcos Vieira', '55566677709', '21211222333411', '61990120020', 'Formosa', 'GO', '1986-08-15'),

-- Clientes
('ana.pereira@gmail.com', 'HASH_ANA', 'cliente', 'Ana Pereira', '67890123456', NULL, '61996789012', 'Brasília', 'DF', '1998-06-05'),
('lucas.almeida@gmail.com', 'HASH_LUCAS', 'cliente', 'Lucas Almeida', '78901234567', NULL, '61997890123', 'Gama', 'DF', '1996-03-22'),
('beatriz.rocha@gmail.com', 'HASH_BEATRIZ', 'cliente', 'Beatriz Rocha', '89012345678', NULL, '61998901234', 'Sobradinho', 'DF', '1999-07-09'),
('gustavo.oliveira@gmail.com', 'HASH_GUSTAVO', 'cliente', 'Gustavo Oliveira', '90123456789', NULL, '61999012345', 'Taguatinga', 'DF', '1995-01-15'),
('juliana.martins@gmail.com', 'HASH_JULIANA', 'cliente', 'Juliana Martins', '01234567890', NULL, '61990123456', 'Goiânia', 'GO', '1993-11-19');
('carolina.ferraz@gmail.com', 'HASH_CAROLINA', 'cliente', 'Carolina Ferraz', '66677788899', NULL, '61995789012', 'Brasília', 'DF', '1994-02-18'),
('rodrigo.pereira@gmail.com', 'HASH_RODRIGO', 'cliente', 'Rodrigo Pereira', '77788899900', NULL, '61996890123', 'Samambaia', 'DF', '1990-07-22'),
('marina.alves@gmail.com', 'HASH_MARINA', 'cliente', 'Marina Alves', '88899900011', NULL, '61997901234', 'Goiânia', 'GO', '1999-04-30'),
('felipe.torres@gmail.com', 'HASH_FELIPE', 'cliente', 'Felipe Torres', '99900011122', NULL, '61998012345', 'Ceilândia', 'DF', '1995-11-07'),
('sofia.cardoso@gmail.com', 'HASH_SOFIA', 'cliente', 'Sofia Cardoso', '00011122233', NULL, '61999123456', 'Brasília', 'DF', '1998-03-25')
('julio.silva@gmail.com', 'HASH_JULIO', 'cliente', 'Júlio Silva', '66677788890', NULL, '61991234570', 'Brasília', 'DF', '1999-09-09'),
('daniela.rodrigues@gmail.com', 'HASH_DANIELA', 'cliente', 'Daniela Rodrigues', '77788899901', NULL, '61992345671', 'Goiânia', 'GO', '1995-12-12'),
('mateus.costa@gmail.com', 'HASH_MATEUS', 'cliente', 'Mateus Costa', '88899900012', NULL, '61993456772', 'Taguatinga', 'DF', '1997-07-17'),
('isabela.moura@gmail.com', 'HASH_ISABELA', 'cliente', 'Isabela Moura', '99900011123', NULL, '61994567873', 'Águas Claras', 'DF', '1996-11-03'),
('fernando.santos@gmail.com', 'HASH_FERNANDO', 'cliente', 'Fernando Santos', '00011122234', NULL, '61995678974', 'Valparaíso', 'GO', '1993-01-26'),
('leticia.oliveira@gmail.com', 'HASH_LETICIA_O', 'cliente', 'Letícia Oliveira', '11122233345', NULL, '61996789075', 'Ceilândia', 'DF', '1998-03-14'),
('pedro.alves@gmail.com', 'HASH_PEDRO', 'cliente', 'Pedro Alves', '22233344456', NULL, '61997890176', 'Gama', 'DF', '1994-06-19'),
('camila.souza@gmail.com', 'HASH_CAMILA_S', 'cliente', 'Camila Souza', '33344455567', NULL, '61998901277', 'Brasília', 'DF', '1997-10-25'),
('henrique.pereira@gmail.com', 'HASH_HENRIQUE', 'cliente', 'Henrique Pereira', '44455566678', NULL, '61999012378', 'Luziânia', 'GO', '1995-09-06'),
('rafaela.machado@gmail.com', 'HASH_RAFAELA', 'cliente', 'Rafaela Machado', '55566677789', NULL, '61990123479', 'Taguatinga', 'DF', '1999-12-20'),
('diego.ramos@gmail.com', 'HASH_DIEGO', 'cliente', 'Diego Ramos', '66677788891', NULL, '61991234580', 'Águas Claras', 'DF', '1993-07-01'),
('bruna.monteiro@gmail.com', 'HASH_BRUNA', 'cliente', 'Bruna Monteiro', '77788899902', NULL, '61992345681', 'Formosa', 'GO', '1998-10-08'),
('gabriel.fernandes@gmail.com', 'HASH_GABRIEL', 'cliente', 'Gabriel Fernandes', '88899900013', NULL, '61993456782', 'Goiânia', 'GO', '1996-02-22'),
('larissa.santos@gmail.com', 'HASH_LARISSA_S', 'cliente', 'Larissa Santos', '99900011124', NULL, '61994567883', 'Brasília', 'DF', '1995-05-11'),
('marcelo.azevedo@gmail.com', 'HASH_MARCELO', 'cliente', 'Marcelo Azevedo', '00011122235', NULL, '61995678984', 'Valparaíso', 'GO', '1990-04-09'),
('bianca.freitas@gmail.com', 'HASH_BIANCA', 'cliente', 'Bianca Freitas', '11122233346', NULL, '61996789085', 'Ceilândia', 'DF', '1999-01-30'),
('leonardo.moraes@gmail.com', 'HASH_LEONARDO', 'cliente', 'Leonardo Moraes', '22233344457', NULL, '61997890186', 'Águas Claras', 'DF', '1997-06-07'),
('carla.ferreira@gmail.com', 'HASH_CARLA', 'cliente', 'Carla Ferreira', '33344455568', NULL, '61998901287', 'Gama', 'DF', '1994-12-16'),
('victor.souza@gmail.com', 'HASH_VICTOR', 'cliente', 'Victor Souza', '44455566679', NULL, '61999012388', 'Taguatinga', 'DF', '1992-03-12'),
('aline.rocha@gmail.com', 'HASH_ALINE_R', 'cliente', 'Aline Rocha', '55566677790', NULL, '61990123489', 'Brasília', 'DF', '1996-08-04')
('tatiane.costa@gmail.com', 'HASH_TATIANE_C', 'cliente', 'Tatiane Costa', '66677788812', NULL, '61991234591', 'Brasília', 'DF', '1994-09-15'),
('joao.paiva@gmail.com', 'HASH_JOAO_P', 'cliente', 'João Paiva', '77788899923', NULL, '61992345692', 'Taguatinga', 'DF', '1995-05-27'),
('mariana.fonseca@gmail.com', 'HASH_MARIANA', 'cliente', 'Mariana Fonseca', '88899900034', NULL, '61993456793', 'Goiânia', 'GO', '1997-01-08'),
('henrique.barros@gmail.com', 'HASH_HENRIQUE_B', 'cliente', 'Henrique Barros', '99900011145', NULL, '61994567894', 'Ceilândia', 'DF', '1992-10-11'),
('clara.menezes@gmail.com', 'HASH_CLARA', 'cliente', 'Clara Menezes', '00011122256', NULL, '61995678995', 'Valparaíso', 'GO', '1998-07-02'),
('rodrigo.fernandes@gmail.com', 'HASH_RODRIGO_F', 'cliente', 'Rodrigo Fernandes', '11122233367', NULL, '61996789096', 'Gama', 'DF', '1996-04-23'),
('amanda.martins@gmail.com', 'HASH_AMANDA', 'cliente', 'Amanda Martins', '22233344478', NULL, '61997890197', 'Sobradinho', 'DF', '1993-02-05'),
('thiago.souza@gmail.com', 'HASH_THIAGO_S', 'cliente', 'Thiago Souza', '33344455589', NULL, '61998901298', 'Brasília', 'DF', '1990-12-17'),
('fernanda.silva@gmail.com', 'HASH_FERNANDA_S', 'cliente', 'Fernanda Silva', '44455566690', NULL, '61999012399', 'Luziânia', 'GO', '1999-06-29'),
('anderson.melo@gmail.com', 'HASH_ANDERSON_M', 'cliente', 'Anderson Melo', '55566677701', NULL, '61990123490', 'Águas Claras', 'DF', '1994-08-09'),
('camila.torres@gmail.com', 'HASH_CAMILA_T', 'cliente', 'Camila Torres', '66677788813', NULL, '61991234592', 'Ceilândia', 'DF', '1997-03-14'),
('luciano.lima@gmail.com', 'HASH_LUCIANO', 'cliente', 'Luciano Lima', '77788899924', NULL, '61992345693', 'Taguatinga', 'DF', '1991-09-20'),
('leticia.nogueira@gmail.com', 'HASH_LETICIA_N', 'cliente', 'Letícia Nogueira', '88899900035', NULL, '61993456794', 'Brasília', 'DF', '1999-02-25'),
('renato.souza@gmail.com', 'HASH_RENATO_S', 'cliente', 'Renato Souza', '99900011146', NULL, '61994567895', 'Valparaíso', 'GO', '1993-11-30'),
('natalia.alves@gmail.com', 'HASH_NATALIA', 'cliente', 'Natália Alves', '00011122257', NULL, '61995678996', 'Gama', 'DF', '1995-07-06'),
('gustavo.moraes@gmail.com', 'HASH_GUSTAVO_M', 'cliente', 'Gustavo Moraes', '11122233368', NULL, '61996789097', 'Sobradinho', 'DF', '1992-05-18'),
('carolina.santos@gmail.com', 'HASH_CAROLINA_S', 'cliente', 'Carolina Santos', '22233344479', NULL, '61997890198', 'Goiânia', 'GO', '1998-01-11'),
('victor.pereira@gmail.com', 'HASH_VICTOR_P', 'cliente', 'Victor Pereira', '33344455590', NULL, '61998901299', 'Taguatinga', 'DF', '1996-06-04'),
('beatriz.mendes@gmail.com', 'HASH_BEATRIZ_M', 'cliente', 'Beatriz Mendes', '44455566601', NULL, '61999012300', 'Brasília', 'DF', '1999-10-19'),
('rafael.goncalves@gmail.com', 'HASH_RAFAEL_G', 'cliente', 'Rafael Gonçalves', '55566677712', NULL, '61990123491', 'Águas Claras', 'DF', '1994-03-01');

-- =======================
-- 6.2. PROVIDER PROFILES
-- =======================
INSERT INTO vimi42.provider_profile (user_id, bio, location)
SELECT id_user, bio, location FROM (
  VALUES
  ((SELECT id_user FROM vimi42.users WHERE email='joao.araujo@techfix.com'), 'Técnico em eletrônica e refrigeração. 10 anos de experiência.', 'Brasília - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='maria.lima@beautyup.com'), 'Manicure e designer de sobrancelhas. Atendimento a domicílio.', 'Goiânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='carlos.mendes@cleanexpress.com'), 'Serviços de limpeza residencial e comercial.', 'Taguatinga - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='fernanda.souza@homecare.com'), 'Cuidadora de idosos e enfermeira técnica.', 'Águas Claras - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='rafael.santos@greenworks.com'), 'Jardinagem e paisagismo sustentável.', 'Valparaíso - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='thiago.costa@hidrotech.com'), 'Especialista em hidráulica e desentupimentos. Atendimento rápido.', 'Brasília - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='patricia.gomes@petlove.com'), 'Banho e tosa profissional para cães e gatos. Atendimento em domicílio.', 'Luziânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='anderson.lopes@movefast.com'), 'Serviço de frete leve e transporte urbano rápido.', 'Taguatinga - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='larissa.oliveira@decorart.com'), 'Design de interiores e decoração personalizada.', 'Águas Claras - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='renato.silva@techhelp.com'), 'Suporte técnico remoto e presencial. Especialista em informática.', 'Formosa - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='camila.dias@fixit.com'), 'Reparos elétricos e domésticos. Serviço confiável e ágil.', 'Brasília - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='eduardo.pinto@eletrik.com'), 'Instalações elétricas industriais e residenciais.', 'Goiânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='aline.martins@cleanhome.com'), 'Limpeza profissional e organização de ambientes.', 'Águas Claras - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='paulo.teixeira@fixhouse.com'), 'Serviços gerais e pequenas reformas.', 'Taguatinga - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='leticia.barros@petclean.com'), 'Banho e tosa ecológicos com produtos naturais.', 'Valparaíso - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='ricardo.alves@greenhouse.com'), 'Projetos de jardinagem moderna e irrigação automatizada.', 'Gama - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='simone.freitas@decorhome.com'), 'Decoração de interiores com foco em sustentabilidade.', 'Luziânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='bruno.carvalho@moveit.com'), 'Serviços de mudança e transporte com agilidade.', 'Ceilândia - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='tatiane.moraes@beautyhome.com'), 'Atendimento de estética facial e corporal em domicílio.', 'Águas Claras - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='gustavo.ramos@techpro.com'), 'Manutenção de computadores e redes corporativas.', 'Formosa - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='luana.castro@hidrosafe.com'), 'Serviços hidráulicos e prevenção de vazamentos.', 'Brasília - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='felipe.melo@eletriccity.com'), 'Eletricista certificado. Instalações e reparos rápidos.', 'Goiânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='sabrina.santos@fixhouse.com'), 'Reformas residenciais e pintura decorativa.', 'Taguatinga - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='rodrigo.lima@greenfix.com'), 'Jardinagem, manutenção e poda de árvores.', 'Valparaíso - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='nathalia.azevedo@petshopcare.com'), 'Cuidadora de pets com experiência veterinária.', 'Gama - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='tiago.martins@cleansafe.com'), 'Limpeza pós-obra e sanitização profissional.', 'Luziânia - GO'),
  ((SELECT id_user FROM vimi42.users WHERE email='aline.ferreira@movehome.com'), 'Transporte e mudanças residenciais seguras.', 'Ceilândia - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='caio.souza@techplus.com'), 'Técnico em informática. Suporte e manutenção remota.', 'Brasília - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='renata.mendes@decorfix.com'), 'Design de ambientes e consultoria estética.', 'Águas Claras - DF'),
  ((SELECT id_user FROM vimi42.users WHERE email='marcos.vieira@hydrocare.com'), 'Hidráulica residencial e industrial.', 'Formosa - GO')
) AS t(user_id, bio, location);

-- =======================
-- 6.3. SERVICES
-- =======================
INSERT INTO vimi42.services (provider_id, categoria, title, description, image)
SELECT provider_id, categoria, title, description, image FROM (
  VALUES
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='joao.araujo@techfix.com'),
    'Refrigeração', 'Instalação de ar-condicionado', 'Instalação e manutenção de ar-condicionados split e janela.', 'https://picsum.photos/seed/ar/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='maria.lima@beautyup.com'),
    'Beleza', 'Design de sobrancelhas', 'Design e coloração de sobrancelhas com henna ou tinta.', 'https://picsum.photos/seed/beauty/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='carlos.mendes@cleanexpress.com'),
    'Limpeza', 'Limpeza pós-obra', 'Equipe especializada em limpeza pesada e detalhada.', 'https://picsum.photos/seed/clean/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='fernanda.souza@homecare.com'),
    'Saúde', 'Cuidadora de idosos', 'Acompanhamento e cuidados diários com idosos e pessoas em recuperação.', 'https://picsum.photos/seed/health/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='rafael.santos@greenworks.com'),
    'Jardinagem', 'Paisagismo residencial', 'Projeto e manutenção de jardins e áreas verdes.', 'https://picsum.photos/seed/garden/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='thiago.costa@hidrotech.com'),
    'Hidráulica', 'Desentupimento e reparos', 'Serviços de desentupimento, vazamentos e instalações hidráulicas.', 'https://picsum.photos/seed/plumbing/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='patricia.gomes@petlove.com'),
    'Pets', 'Banho e tosa completa', 'Higienização e cuidado com seu pet, com produtos naturais.', 'https://picsum.photos/seed/pet/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='anderson.lopes@movefast.com'),
    'Frete', 'Transporte urbano leve', 'Entregas rápidas e seguras de móveis, caixas e encomendas.', 'https://picsum.photos/seed/frete/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='larissa.oliveira@decorart.com'),
    'Decoração', 'Consultoria de interiores', 'Planejamento e design de ambientes residenciais e comerciais.', 'https://picsum.photos/seed/decor/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='renato.silva@techhelp.com'),
    'Tecnologia', 'Formatação e suporte técnico', 'Formatação, remoção de vírus e manutenção preventiva.', 'https://picsum.photos/seed/tech/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='camila.dias@fixit.com'),
    'Elétrica', 'Reparos e instalações elétricas', 'Troca de tomadas, disjuntores e instalações residenciais seguras.', 'https://picsum.photos/seed/eletrica1/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='eduardo.pinto@eletrik.com'),
    'Elétrica', 'Projetos elétricos industriais', 'Planejamento e execução de instalações elétricas industriais.', 'https://picsum.photos/seed/eletrica2/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='aline.martins@cleanhome.com'),
    'Limpeza', 'Limpeza e organização residencial', 'Limpeza detalhada e organização de casas e apartamentos.', 'https://picsum.photos/seed/cleanhome/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='paulo.teixeira@fixhouse.com'),
    'Serviços Gerais', 'Reformas e pequenos reparos', 'Pintura, reboco, montagem e manutenção em geral.', 'https://picsum.photos/seed/reformas1/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='leticia.barros@petclean.com'),
    'Pets', 'Banho e tosa ecológicos', 'Produtos biodegradáveis e técnicas sem estresse para os pets.', 'https://picsum.photos/seed/petclean/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='ricardo.alves@greenhouse.com'),
    'Jardinagem', 'Irrigação e manutenção de jardins', 'Instalação de sistemas de irrigação e poda profissional.', 'https://picsum.photos/seed/greenhouse/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='simone.freitas@decorhome.com'),
    'Decoração', 'Interiores sustentáveis', 'Consultoria em decoração eco-friendly e minimalista.', 'https://picsum.photos/seed/decorhome/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='bruno.carvalho@moveit.com'),
    'Frete', 'Mudanças rápidas e seguras', 'Transporte de móveis e mudanças urbanas com embalagem inclusa.', 'https://picsum.photos/seed/moveit/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='tatiane.moraes@beautyhome.com'),
    'Beleza', 'Massagem e estética facial', 'Tratamentos corporais e faciais em domicílio.', 'https://picsum.photos/seed/beautyhome/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='gustavo.ramos@techpro.com'),
    'Tecnologia', 'Manutenção de redes e PCs', 'Instalação, suporte e monitoramento de redes corporativas.', 'https://picsum.photos/seed/techpro/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='luana.castro@hidrosafe.com'),
    'Hidráulica', 'Reparos hidráulicos e emergenciais', 'Atendimento rápido em vazamentos e entupimentos.', 'https://picsum.photos/seed/hidrosafe/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='felipe.melo@eletriccity.com'),
    'Elétrica', 'Instalações elétricas residenciais', 'Instalação de luminárias, ventiladores e disjuntores.', 'https://picsum.photos/seed/eletriccity/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='sabrina.santos@fixhouse.com'),
    'Reformas', 'Pintura e acabamento', 'Pintura decorativa e reformas residenciais.', 'https://picsum.photos/seed/fixhouse/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='rodrigo.lima@greenfix.com'),
    'Jardinagem', 'Poda e manutenção de áreas verdes', 'Corte, adubagem e revitalização de jardins.', 'https://picsum.photos/seed/greenfix/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='nathalia.azevedo@petshopcare.com'),
    'Pets', 'Cuidados e hospedagem para pets', 'Hospedagem, passeios e cuidados veterinários básicos.', 'https://picsum.photos/seed/petshopcare/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='tiago.martins@cleansafe.com'),
    'Limpeza', 'Sanitização e limpeza pesada', 'Desinfecção de ambientes com produtos profissionais.', 'https://picsum.photos/seed/cleansafe/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='aline.ferreira@movehome.com'),
    'Frete', 'Transporte e mudanças residenciais', 'Serviço rápido, seguro e com embalagens inclusas.', 'https://picsum.photos/seed/movehome/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='caio.souza@techplus.com'),
    'Tecnologia', 'Suporte e manutenção remota', 'Atendimento técnico online e presencial.', 'https://picsum.photos/seed/techplus/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='renata.mendes@decorfix.com'),
    'Decoração', 'Design de ambientes modernos', 'Consultoria e criação de espaços aconchegantes.', 'https://picsum.photos/seed/decorfix/400'),
  ((SELECT provider_id FROM vimi42.provider_profile p JOIN vimi42.users u ON p.user_id=u.id_user WHERE u.email='marcos.vieira@hydrocare.com'),
    'Hidráulica', 'Hidráulica industrial e residencial', 'Projetos e manutenções de sistemas hidráulicos completos.', 'https://picsum.photos/seed/hydrocare/400')
) AS t(provider_id, categoria, title, description, image);

-- =======================
-- 6.4. SERVICE REQUESTS (agendamentos) - 25 registros aleatórios
-- =======================
INSERT INTO vimi42.service_request (provider_id, user_id, service_id, status, schedule_at)
SELECT 
  s.provider_id,
  u.id_user,
  s.service_id,
  CASE
    WHEN random() < 0.2 THEN 'aguardando confirmação'
    WHEN random() < 0.4 THEN 'aceito'
    WHEN random() < 0.6 THEN 'em andamento'
    WHEN random() < 0.8 THEN 'concluído'
    ELSE 'cancelado'
  END,
  now() - (random() * interval '15 days')
FROM vimi42.services s
JOIN vimi42.users u ON u.email IN (
  'ana.pereira@gmail.com',
  'lucas.almeida@gmail.com',
  'beatriz.rocha@gmail.com',
  'gustavo.oliveira@gmail.com',
  'juliana.martins@gmail.com',
  'carolina.ferraz@gmail.com',
  'rodrigo.pereira@gmail.com',
  'marina.alves@gmail.com',
  'felipe.torres@gmail.com',
  'sofia.cardoso@gmail.com',
  'rafaela.gomes@gmail.com',
  'henrique.moraes@gmail.com',
  'aline.silva@gmail.com',
  'thiago.souza@gmail.com',
  'camila.ramos@gmail.com'
)
LIMIT 25;

-- =======================
-- 6.5. REVIEWS
-- =======================
INSERT INTO vimi42.reviews (request_id, rating, comment)
SELECT request_id, rating, comment FROM (
  VALUES
  ((SELECT request_id FROM vimi42.service_request LIMIT 1 OFFSET 0), 5, 'Excelente profissional! Trabalho impecável.'),
  ((SELECT request_id FROM vimi42.service_request LIMIT 1 OFFSET 1), 4, 'Atendimento ótimo, muito simpática.'),
  ((SELECT request_id FROM vimi42.service_request LIMIT 1 OFFSET 2), 5, 'Serviço rápido e eficiente. Recomendo!'),
  ((SELECT request_id FROM vimi42.service_request LIMIT 1 OFFSET 3), 3, 'Boa profissional, mas chegou com atraso.'),
  ((SELECT request_id FROM vimi42.service_request LIMIT 1 OFFSET 4), 5, 'Transformou meu jardim! Excelente gosto.'),
  ((SELECT request_id FROM vimi42.service_request ORDER BY request_id DESC LIMIT 1 OFFSET 0), 5, 'Excelente profissional, resolveu meu problema em minutos!'),
  ((SELECT request_id FROM vimi42.service_request ORDER BY request_id DESC LIMIT 1 OFFSET 1), 4, 'Muito atenciosa com os pets, recomendo.'),
  ((SELECT request_id FROM vimi42.service_request ORDER BY request_id DESC LIMIT 1 OFFSET 2), 5, 'Frete rápido e seguro, ótima experiência.'),
  ((SELECT request_id FROM vimi42.service_request ORDER BY request_id DESC LIMIT 1 OFFSET 3), 5, 'A decoração ficou incrível! Super recomendo.'),
  ((SELECT request_id FROM vimi42.service_request ORDER BY request_id DESC LIMIT 1 OFFSET 4), 4, 'Atendimento remoto eficiente, salvou meu notebook.')
) AS t(request_id, rating, comment);
-- ========================================
-- FIM init.sql
-- ========================================