const mysql = require('mysql2');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const Sequelize = require('sequelize');

class SequelizeRepository {
    async initialize(config, logger) {
        this.config = config;
        this.logger = logger;

        this.setEnvParameters();
        await this.createDatabaseIfNotExists();
        await this.runMigrations();

        this.models = await this.loadModels();
    }

    setEnvParameters() {
        process.env.SEQUELIZE_REPOSITORY_USER = this.config.user;
        process.env.SEQUELIZE_REPOSITORY_PASSWORD = this.config.password;
        process.env.SEQUELIZE_REPOSITORY_DATABASE = this.config.database;
        process.env.SEQUELIZE_REPOSITORY_HOST = this.config.host;
        process.env.SEQUELIZE_REPOSITORY_PORT = this.config.port;
        process.env.SEQUELIZE_REPOSITORY_DIALECT = this.config.dialect;
    }

    async createDatabaseIfNotExists() {
        const connection = await mysql.createConnection({
            host: this.config.host,
            port: this.config.port,
            user: this.config.user,
            password: this.config.password,
        });
        // todo remove drop!!!
        await connection.promise().query(`DROP DATABASE IF EXISTS \`${this.config.database}\`;`);
        await connection.promise().query(`CREATE DATABASE IF NOT EXISTS \`${this.config.database}\`;`);
    }

    async runMigrations() {
        return new Promise((resolve, reject) => {
            const configurationPath = path.join(__dirname, 'config', 'sequelizeConfig.js');
            const migrationFolderPath = path.join(__dirname, 'migrations');
            const migrate = exec(
                `npx sequelize --config=${configurationPath} --migrations-path=${migrationFolderPath} db:migrate`,
                { env: process.env },
                (err) => (err ? reject(err) : resolve()),
            );
            if (this.config.logging) {
                // Forward stdout+stderr to this process
                migrate.stdout.pipe(process.stdout);
                migrate.stderr.pipe(process.stderr);
            }
        });
    }

    async loadModels() {
        const modelsDirectory = path.join(__dirname, 'models');
        // disable automatic timestamps
        this.config.define = {
            timestamps: false,
            freezeTableName: true,
        };
        const sequelize = new Sequelize(
            this.config.database,
            this.config.user,
            this.config.password,
            this.config,
        );
        const models = {};
        fs.readdirSync(modelsDirectory)
            .filter((file) => file.indexOf('.') !== 0 && file.slice(-3) === '.js')
            .forEach((file) => {
                // eslint-disable-next-line global-require,import/no-dynamic-require
                const model = require(path.join(modelsDirectory, file))(
                    sequelize,
                    Sequelize.DataTypes,
                );
                models[model.name] = model;
            });

        Object.keys(models).forEach((modelName) => {
            if (models[modelName].associate) {
                models[modelName].associate(models);
            }
        });
        models.sequelize = sequelize;
        models.Sequelize = Sequelize;

        return models;
    }

    // HANDLER_ID
    async createHandlerIdRecord(handlerData) {
        const handlerRecord = await this.models.handler_ids.create(handlerData);
        return handlerRecord;
    }

    async getHandlerIdRecord(handlerId) {
        const handlerRecord = await this.models.handler_ids.findOne({
            where: {
                handler_id: handlerId,
            }
        });
        return handlerRecord;
    }

    async updateHandlerIdRecord(data, handlerId) {
        await this.models.handler_ids.update(data, {
            where: {
                handler_id: handlerId,
            },
        });
    }

    // PUBLISH
    async createPublishRecord(status) {
        return this.models.publish.create({status});
    }

    // RESOLVE
    async createResolveRecord(status) {
        return this.models.resolve.create({status});
    }

    async updatePublishRecord(data, publishId) {
        await this.models.publish.update(data, {
            where: {
                id: publishId,
            },
        });
    }

    async getNumberOfNodesFoundForPublish(publishId){
        return this.models.publish.findOne({
            attributes: ['nodes_found'],
            where: {
                id: publishId,
            }
        })
    }

    // PUBLISH RESPONSE
    async createPublishResponseRecord(status, publishId, message) {
        await this.models.publish_response.create({
            status,
            message,
            publish_id: publishId,
        })
    }

    // RESOLVE RESPONSE
    async createResolveResponseRecord(status, resolveId, message) {
        await this.models.resolve_response.create({
            status,
            message,
            resolveId,
        })
    }

    async getNumberOfPublishResponses(publishId) {
        return this.models.publish_response.count({
            where: {
                publish_id: publishId,
            }
        })
    }

    async getNumberOfResolveResponses(resolveId) {
        return this.models.resolve_response.count({
            where: {
                resolveId,
            }
        })
    }
}

module.exports = SequelizeRepository;
