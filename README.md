# tangnano20k-vectrex
Tang Nano 20K top level module for Dar's Vectrex

## 概要
- Vectrex by Dar (darfpga@aol.fr) http://darfpga.blogspot.fr をTang Nano 20Kで動作させるためのトップレベルモジュール，オシロスコープ用信号出力のためのDAC(MCP4911)用モジュール，および周辺回路の回路図です．
- とりあえず作ってみただけなので，動作は完全ではありませんし，デバッグ用のコード等も入っています．
- [SourceForge DarFPGA](https://sourceforge.net/projects/darfpga/files/Software%20VHDL/vectrex/)にあったDE10-lite用のソースを改変して作りました．
- オリジナルのパッケージのREADME.TXTにあるように，下記のことを理解した上でご使用下さい．
  - Educational use only
  - Do not redistribute synthetized file with roms
  - Do not redistribute roms whatever the form
  - Use at your own risk

### rev0.3 (まだ改善の余地があり，改版予定ありです．)
- VGA出力用のコードと回路は削除して，XYモニター(オシロスコープ)用の出力専用にしました．
- Sony WatchmanをXYモニタに改造するための回路を追加しました．
- コントローラーをアナログ対応にしました．TangNano20kゲームキットのコントローラは粗くてスティックの稼働範囲も狭いので，SONY純正のDualShock 2(SCPH-10010)をお薦めします．
- 基板を作ってみました．ブレッドボード版のノイズが改善されるかと思ったのですが改善されませんでした．

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
- "Project->Configuration->Dual-Purpose Pin->Use SSPI as regular IO"をチェックして下さい
- ROMデータのファイルは，プロジェクトに適宜追加・削除して下さい．

## ROMデータについて
- このレポジトリにはROMデータはありません．(romフォルダにあるのは空のテンプレートファイルです．)
- 必要なROMデータは何らかの方法で入手して，オリジナルのパッケージに含まれるREADME.TXTに従ってvhdlファイルを作成して下さい．
- データをVHDLに変換するスクリプトrom/rom2vhd.pl を使ってもいいかも．
- romの名前，サイズに応じて，rtl_dar/vectrex.vhdを適宜修正して下さい．

## その他
- このプロジェクトはあくまでFPGAを使う練習用の試みなので，バグ等があってもメンテナンスをする予定はありません．

## 更新履歴
- 2023/6/13: 初版公開
- 2023/6/13: 回路図にLPFが抜けていたので追加
- 2023/11/14: rev0.3公開．初版はold/rev0.1に移動．
