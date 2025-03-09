# センチュリー・システムズのルーターにlighttpdをインストールしてCGIを有効にする方法

この記事では、センチュリー・システムズのLTEルーター（Ubuntu上で動作）にlighttpdをインストールし、CGIを有効にしてシェルスクリプトを動作させる手順を説明します。

## 必要なもの

- センチュリー・システムズのLTEルーター
- インターネット接続
- SSHアクセス

## 手順

1. **Ubuntuでのlighttpdのインストール**

   まず、ルーターにSSHでアクセスし、以下のコマンドを実行してlighttpdをインストールします。

   ```bash
   sudo apt update
   sudo apt install lighttpd
   ```

2. **CGIの有効化**

   次に、lighttpdの設定ファイルを編集してCGIを有効にします。設定ファイルは通常`/etc/lighttpd/lighttpd.conf`にあります。

   ```bash
   vi /etc/lighttpd/lighttpd.conf
   ```

   設定ファイル内で以下の行を追加または編集します。

   ```conf
   server.modules += ( "mod_cgi" )
   cgi.assign = ( ".sh" => "/bin/sh" )
   ```

3. **シェルスクリプトの配置**

   CGIとして動作させたいシェルスクリプトを`/www/cgi-bin/`ディレクトリに配置します。スクリプトに実行権限を付与することを忘れないでください。

   ```bash
   chmod +x /www/cgi-bin/your-script.sh
   ```

4. **lighttpdの再起動**

   設定を反映させるためにlighttpdを再起動します。

   ```bash
   /etc/init.d/lighttpd restart
   ```

## 結論

これで、センチュリー・システムズのルーター上でlighttpdを使用してCGIを有効にし、シェルスクリプトを実行できるようになりました。これにより、ルーター上での自動化やカスタムスクリプトの実行が可能になります。
