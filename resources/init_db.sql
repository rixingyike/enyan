-- Database Schema and Mock Data for Grace Words

CREATE TABLE IF NOT EXISTS version (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    short_name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS book (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    short_name TEXT NOT NULL,
    chapter_count INTEGER NOT NULL,
    testament TEXT NOT NULL -- 'OT' or 'NT'
);

CREATE TABLE IF NOT EXISTS verse (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book_id INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    content TEXT NOT NULL,
    version_id INTEGER NOT NULL,
    FOREIGN KEY(book_id) REFERENCES book(id),
    FOREIGN KEY(version_id) REFERENCES version(id)
);

-- Insert Version
INSERT INTO version (id, name, short_name) VALUES (1, 'Chinese Union Version', 'CUV');

-- Insert Books (Sample: Genesis, Psalms, John, Romans)
INSERT INTO book (id, name, short_name, chapter_count, testament) VALUES 
(1, '创世记', '创', 50, 'OT'),
(19, '诗篇', '诗', 150, 'OT'),
(43, '约翰福音', '约', 21, 'NT'),
(45, '罗马书', '罗', 16, 'NT');

-- Insert Verses (Sample: John 3:16, Psalm 23:1)
-- John 3:16
INSERT INTO verse (book_id, chapter, verse, content, version_id) VALUES 
(43, 3, 16, '神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不至灭亡，反得永生。', 1);

-- Psalm 23
INSERT INTO verse (book_id, chapter, verse, content, version_id) VALUES 
(19, 23, 1, '耶和华是我的牧者，我必不致缺乏。', 1),
(19, 23, 2, '他使我躺卧在青草地上，领我在可安歇的水边。', 1),
(19, 23, 3, '他使我的灵魂苏醒，为自己的名引导我走义路。', 1),
(19, 23, 4, '我虽然行过死荫的幽谷，也不怕遭害，因为你与我同在；你的杖，你的竿，都安慰我。', 1),
(19, 23, 5, '在我敌人面前，你为我摆设筵席；你用油膏了我的头，使我的福杯满溢。', 1),
(19, 23, 6, '我一生一世必有恩惠慈爱随着我；我且要住在耶和华的殿中，直到永远。', 1);

-- Genesis 1:1
INSERT INTO verse (book_id, chapter, verse, content, version_id) VALUES 
(1, 1, 1, '起初，神创造天地。', 1);
