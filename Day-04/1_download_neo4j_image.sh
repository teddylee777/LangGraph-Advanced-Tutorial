#!/bin/bash

###############################################################################
# Neo4j Community Edition 다운로드 스크립트
# Google Drive에서 Neo4j tar 파일을 다운로드합니다.
###############################################################################

set -e  # 오류 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Google Drive 파일 정보
FILE_ID="1hO0RfmkwClqZNqJBjPu4XaHX9EbsRERw"
OUTPUT_FILE="neo4j-5.24.2-community-linux-amd64.tar"

###############################################################################
# 함수: 메시지 출력
###############################################################################
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

###############################################################################
# 함수: wget 또는 curl 설치 확인 및 설치
###############################################################################
check_and_install_tools() {
    local has_wget=false
    local has_curl=false
    
    # wget 확인
    if command -v wget &> /dev/null; then
        has_wget=true
        print_info "wget이 이미 설치되어 있습니다."
    fi
    
    # curl 확인
    if command -v curl &> /dev/null; then
        has_curl=true
        print_info "curl이 이미 설치되어 있습니다."
    fi
    
    # 둘 다 없으면 설치
    if [ "$has_wget" = false ] && [ "$has_curl" = false ]; then
        print_warning "wget과 curl이 모두 설치되어 있지 않습니다."
        print_info "필요한 도구를 설치합니다..."
        
        # OS 감지
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
        else
            print_error "OS를 감지할 수 없습니다."
            exit 1
        fi
        
        # 패키지 관리자에 따라 설치
        case $OS in
            ubuntu|debian)
                print_info "Ubuntu/Debian 시스템 감지. apt를 사용하여 설치합니다."
                sudo apt-get update
                sudo apt-get install -y wget curl
                ;;
            centos|rhel|fedora)
                print_info "CentOS/RHEL/Fedora 시스템 감지. yum/dnf를 사용하여 설치합니다."
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y wget curl
                else
                    sudo yum install -y wget curl
                fi
                ;;
            *)
                print_error "지원하지 않는 OS입니다: $OS"
                print_error "wget 또는 curl을 수동으로 설치해주세요."
                exit 1
                ;;
        esac
        
        print_success "wget과 curl 설치 완료!"
    fi
}

###############################################################################
# 함수: Google Drive에서 파일 다운로드
###############################################################################
download_from_google_drive() {
    local file_id=$1
    local output_file=$2
    
    print_info "Google Drive에서 파일을 다운로드합니다..."
    print_info "파일 ID: $file_id"
    print_info "출력 파일: $output_file"
    
    # 임시 쿠키 파일
    local cookie_file=$(mktemp)
    
    # wget이 있으면 wget 사용
    if command -v wget &> /dev/null; then
        print_info "wget을 사용하여 다운로드합니다..."
        
        # 먼저 확인 토큰을 얻기 위한 요청
        wget --quiet --save-cookies "$cookie_file" \
             --keep-session-cookies \
             --no-check-certificate \
             "https://drive.google.com/uc?export=download&id=$file_id" \
             -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' > /tmp/confirm.txt
        
        local confirm_code=$(cat /tmp/confirm.txt)
        
        # 실제 파일 다운로드
        if [ -z "$confirm_code" ]; then
            # 확인 코드가 필요없는 경우 (작은 파일)
            wget --load-cookies "$cookie_file" \
                 --no-check-certificate \
                 "https://drive.google.com/uc?export=download&id=$file_id" \
                 -O "$output_file"
        else
            # 확인 코드가 필요한 경우 (큰 파일)
            wget --load-cookies "$cookie_file" \
                 --no-check-certificate \
                 "https://drive.google.com/uc?export=download&confirm=$confirm_code&id=$file_id" \
                 -O "$output_file"
        fi
        
        rm -f /tmp/confirm.txt
        
    # curl이 있으면 curl 사용
    elif command -v curl &> /dev/null; then
        print_info "curl을 사용하여 다운로드합니다..."
        
        # 먼저 확인 토큰을 얻기 위한 요청
        curl -c "$cookie_file" -s -L \
             "https://drive.google.com/uc?export=download&id=$file_id" \
             | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' > /tmp/confirm.txt
        
        local confirm_code=$(cat /tmp/confirm.txt)
        
        # 실제 파일 다운로드
        if [ -z "$confirm_code" ]; then
            # 확인 코드가 필요없는 경우
            curl -Lb "$cookie_file" \
                 "https://drive.google.com/uc?export=download&id=$file_id" \
                 -o "$output_file"
        else
            # 확인 코드가 필요한 경우
            curl -Lb "$cookie_file" \
                 "https://drive.google.com/uc?export=download&confirm=$confirm_code&id=$file_id" \
                 -o "$output_file"
        fi
        
        rm -f /tmp/confirm.txt
    else
        print_error "wget과 curl이 모두 없습니다. 설치에 실패했습니다."
        rm -f "$cookie_file"
        exit 1
    fi
    
    # 쿠키 파일 삭제
    rm -f "$cookie_file"
}

###############################################################################
# 함수: 다운로드 파일 검증
###############################################################################
verify_download() {
    local file=$1
    
    if [ ! -f "$file" ]; then
        print_error "다운로드된 파일을 찾을 수 없습니다: $file"
        return 1
    fi
    
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [ "$file_size" -lt 1000000 ]; then
        print_error "다운로드된 파일이 너무 작습니다 ($file_size bytes)."
        print_error "Google Drive 오류 페이지가 다운로드되었을 수 있습니다."
        return 1
    fi
    
    print_success "파일 다운로드 성공! (크기: $(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "$file_size bytes"))"
    return 0
}

###############################################################################
# 메인 실행
###############################################################################
main() {
    print_info "=== Neo4j Community Edition 다운로드 스크립트 시작 ==="
    echo ""
    
    # 1. 필요한 도구 확인 및 설치
    print_info "[1/3] 필요한 도구 확인 및 설치"
    check_and_install_tools
    echo ""
    
    # 2. 이미 파일이 있는지 확인
    if [ -f "$OUTPUT_FILE" ]; then
        print_warning "파일이 이미 존재합니다: $OUTPUT_FILE"
        read -p "다시 다운로드하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "다운로드를 취소합니다."
            exit 0
        fi
        rm -f "$OUTPUT_FILE"
    fi
    
    # 3. Google Drive에서 다운로드
    print_info "[2/3] Google Drive에서 파일 다운로드"
    download_from_google_drive "$FILE_ID" "$OUTPUT_FILE"
    echo ""
    
    # 4. 다운로드 검증
    print_info "[3/3] 다운로드 검증"
    if verify_download "$OUTPUT_FILE"; then
        echo ""
        print_success "=== 모든 작업이 완료되었습니다! ==="
        print_info "다운로드된 파일: $OUTPUT_FILE"
        print_info ""
        print_info "압축 해제 방법:"
        print_info "  tar -xf $OUTPUT_FILE"
    else
        print_error "=== 다운로드에 실패했습니다 ==="
        exit 1
    fi
}

# 스크립트 실행
main

