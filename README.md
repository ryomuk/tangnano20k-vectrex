# tangnano20k-vectrex
Tang Nano 20K top level module for Dar's Vectrex

## 概要
- Tang Nano 20K用のトップレベルモジュール，オシロスコープ用信号出力のためのDAC(MCP4922)用モジュール，および周辺回路の回路図です．
- とりあえず作ってみただけなので，動作は完全ではありませんし，デバッグ用のコード等も入っています．
- [SourceForge DarFPGA](https://sourceforge.net/projects/darfpga/files/Software%20VHDL/vectrex/)にあったDE10-lite用のソースを改変して作りました．
- オリジナルのパッケージのREADME.TXTにあるように，下記のことを理解した上でご使用下さい．
  - Educational use only
  - Do not redistribute synthetized file with roms
  - Do not redistribute roms whatever the form
  - Use at your own risk

### [Tang Nano 9K版](https://github.com/ryomuk/tangnano9k-vectrex)との主な差分
- コントローラーをゲームキットのコントローラに変更(1人用，デジタルのみ対応)
- VGA出力信号に抵抗をはさみました．
- XYモニター(オシロスコープ)用の信号を出力するようにしました．

## コンパイル方法

1. [SourceForge DarFPGA](https://sourceforge.net/projects/darfpga/files/Software%20VHDL/vectrex/)にある vhdl_vectrex_rev_0_2_2018_06_12.zip を展開する．
2. 展開してできた下記フォルダを，vectrex_project/src/に中身ごとコピーする．
```
cp -a rtl_dar rtl_jkent rtl_mikej rtl_pace vectrex_project/src/
```
3. ROMデータのvhdlファイルを用意して，romフォルダを作成してそこに置く．
```
mkdir vectrex_project/src/rom
cp vectrex_exec_prom.vhd vectrex_project/src/rom/ (必須)
cp vectrex_scramble_prom.vhd vectrex_project/src/rom/ (ゲームROMデータの例)
```
4. Gowin EDAでプロジェクト vectrex_project.gprj を開いてビルドする．
(ROMデータのファイルは，プロジェクトに適宜追加・削除して下さい．)

## ROMデータについて
- 必要なROMデータは何らかの方法で入手して，オリジナルのパッケージに含まれるREADME.TXTに従ってvhdlファイルを作成して下さい．
- romの名前，サイズに応じて，rtl_dar/vectrex.vhdを適宜修正して下さい．(やり方はソースのコメントに書いてあります．)

## その他
- 27MHzのクロックを25MHzとして使っています．Tang NanoのPLLで25MHzのクロックが作れるかもしれないのでその方がいいかも．(私はIPを使いたくなかったので27MHzのクロックのまま使っています．)
- このプロジェクトはあくまでFPGAを使う練習用の試みなので，バグ等があってもメンテナンスをする予定はありません．
