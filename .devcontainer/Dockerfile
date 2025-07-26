FROM debian:bullseye-slim

# bash を既定のシェルにする
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージのインストール
RUN apt-get update && \
    apt-get install -y curl git wget unzip zip xz-utils sudo openjdk-17-jdk && \
    rm -rf /var/lib/apt/lists/*

# 開発者ユーザーの追加とsudo権限の付与
RUN useradd -ms /bin/bash developer
RUN echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 開発者ユーザーのホームディレクトリを設定
ENV HOME=/home/developer

# # Java(Zulu OpenJDK)のインストール
# ENV JAVA_HOME=/opt/zulu17.56.15-ca-jdk17.0.14-linux_x64

# RUN wget -P /tmp/ https://cdn.azul.com/zulu/bin/zulu17.56.15-ca-jdk17.0.14-linux_x64.zip
# RUN unzip /tmp/zulu17.56.15-ca-jdk17.0.14-linux_x64.zip -d /opt

# # Javaのパスを設定
# ENV PATH=/opt/zulu17.56.15-ca-jdk17.0.14-linux_x64/bin:$PATH

# # Android SDKのインストールと設定
# ENV ANDROID_SDK_ROOT=/opt/Android/sdk
# ENV ANDROID_HOME=$ANDROID_SDK_ROOT

# # Android SDK コマンドラインツールの展開とディレクトリ整理
# RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools
# # Android command-line tools のダウンロード
# RUN wget -P /tmp/ https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
# RUN unzip /tmp/commandlinetools-linux-11076708_latest.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools/ && \
# mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest

# # Android cmdline-tools のパスを追加
# ENV PATH=${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:$PATH
# ENV PATH=${ANDROID_SDK_ROOT}/platform-tools:$PATH
# ENV PATH=${ANDROID_SDK_ROOT}/platforms:$PATH

# Flutter SDKのインストールと設定
ENV FLUTTER_ROOT=/opt/flutter

# Flutter SDK のダウンロードと展開
RUN wget -P /tmp https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.4-stable.tar.xz && \
    tar -xf /tmp/flutter_linux_3.24.4-stable.tar.xz -C /opt/

# Flutterのパスを設定
ENV PATH=${FLUTTER_ROOT}/bin:$PATH

# 不要なファイルを削除
RUN rm -rf /tmp/*
# 各種ディレクトリの所有者を開発者ユーザーに変更
RUN chown -R developer:developer /opt/*

# 開発者ユーザーに切り替え
USER developer
# 作業ディレクトリを設定
WORKDIR $HOME

# # Android SDK の各コンポーネントを sdkmanager でインストール（yesで自動応答）
# RUN yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "platforms;android-34" "build-tools;33.0.1"

# Android ライセンスに同意
# RUN yes | flutter doctor --android-licenses
# Flutter の初回設定（analytics無効化）
RUN flutter --disable-analytics

# コンテナ起動時にbashを実行
CMD ["/bin/bash"]
