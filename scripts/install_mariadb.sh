#!/bin/bash
# MariaDB ColumnStore Installation Script (Updated)
# Supports: Ubuntu 20.04/22.04, Debian 11/12
# Uses the official MariaDB ColumnStore installation method

set -e  # Exit on error

echo "🚀 MariaDB ColumnStore Installation (Updated)"
echo "=============================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "❌ Cannot detect OS. Please install manually."
    exit 1
fi

echo "📋 Detected: $OS $VERSION"

# Install based on OS
case $OS in
    ubuntu|debian)
        echo "📦 Installing MariaDB ColumnStore for $OS..."
        
        # Update system
        echo "🔄 Updating system packages..."
        sudo apt update
        sudo apt upgrade -y
        
        # Install prerequisites
        echo "📦 Installing prerequisites..."
        sudo apt install -y wget curl software-properties-common gnupg2
        
        # Add MariaDB repository using official setup script
        echo "📥 Adding MariaDB repository..."
        curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=11.1
        
        # Install MariaDB Server with ColumnStore
        echo "📦 Installing MariaDB Server and ColumnStore..."
        sudo apt-get -y install mariadb-server mariadb-plugin-columnstore mariadb-columnstore-cmapi
        
        # Enable services
        echo "🔧 Enabling MariaDB services..."
        sudo systemctl enable mariadb
        sudo systemctl enable mariadb-columnstore-cmapi
        
        # Start services
        echo "🚀 Starting MariaDB services..."
        sudo systemctl start mariadb
        sudo systemctl start mariadb-columnstore-cmapi
        
        echo "✅ MariaDB ColumnStore installed successfully!"
        ;;
        
    centos|rhel|rocky)
        echo "📦 Installing MariaDB ColumnStore for $OS..."
        
        # Add MariaDB repository using official setup script
        echo "📥 Adding MariaDB repository..."
        curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=11.1
        
        # Install MariaDB Server with ColumnStore
        echo "📦 Installing MariaDB Server and ColumnStore..."
        sudo dnf install -y MariaDB-server MariaDB-columnstore-engine MariaDB-columnstore-cmapi
        
        # Enable services
        echo "🔧 Enabling MariaDB services..."
        sudo systemctl enable mariadb
        sudo systemctl enable mariadb-columnstore-cmapi
        
        # Start services
        echo "🚀 Starting MariaDB services..."
        sudo systemctl start mariadb
        sudo systemctl start mariadb-columnstore-cmapi
        
        echo "✅ MariaDB ColumnStore installed successfully!"
        ;;
        
    *)
        echo "❌ Unsupported OS: $OS"
        echo "Please install MariaDB manually from: https://mariadb.com/downloads/"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "🔍 Verifying installation..."
if systemctl is-active --quiet mariadb; then
    echo "✅ MariaDB service is running"
else
    echo "❌ MariaDB service is not running"
    exit 1
fi

if systemctl is-active --quiet mariadb-columnstore-cmapi; then
    echo "✅ MariaDB ColumnStore CMAPI service is running"
else
    echo "⚠️  MariaDB ColumnStore CMAPI service is not running"
fi

# ColumnStore cluster configuration
echo ""
echo "🔧 Configuring ColumnStore cluster..."

# Set API key (you should change this to a secure key)
echo "🔑 Setting cluster API key..."
echo "⚠️  Please replace 'your_cluster_api_key' with a secure API key"
sudo mcs cluster set api-key --key your_cluster_api_key || echo "⚠️  API key setup failed - please configure manually"

# Add local node to cluster
echo "🖥️  Adding local node to cluster..."
sudo mcs cluster node add --node 127.0.0.1 || echo "⚠️  Node addition failed - please configure manually"

# Copy ColumnStore configuration
echo "📋 Copying ColumnStore configuration..."
if [ -f "config/mariadb_columnstore.cnf" ]; then
    sudo cp config/mariadb_columnstore.cnf /etc/mysql/mariadb.conf.d/z-columnstore.cnf
    echo "✅ ColumnStore configuration copied"
    
    # Restart MariaDB to apply configuration
    echo "🔄 Restarting MariaDB to apply configuration..."
    sudo systemctl restart mariadb
else
    echo "⚠️  Configuration file not found: config/mariadb_columnstore.cnf"
    echo "    Please ensure you're running this script from the project root directory"
fi

# Test ColumnStore plugin
echo ""
echo "🔍 Testing ColumnStore plugin..."
sudo mysql -e "SHOW ENGINES;" | grep -i columnstore && \
    echo "✅ ColumnStore engine available" || \
    echo "⚠️  ColumnStore engine not found - may need manual configuration"

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Next steps:"
echo "1. Secure your installation: sudo mysql_secure_installation"
echo "2. Update the API key in the cluster configuration"
echo "3. Verify ColumnStore is working: sudo mcs cluster status"
echo "4. Run setup script: ./scripts/setup.sh"
echo ""
echo "📚 For troubleshooting, check:"
echo "   - MariaDB logs: sudo journalctl -u mariadb"
echo "   - ColumnStore logs: sudo journalctl -u mariadb-columnstore-cmapi"
